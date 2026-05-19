// mobile/lib/features/store_dashboard/screens/menu_overview_screen.dart
//
// Màn hình quản lý menu cho store_owner.
// Route: /store-dashboard/:storeId/menu

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_models.dart';
import '../menu/providers/menu_provider.dart';
import 'menu_item_form_screen.dart';

class MenuOverviewScreen extends ConsumerWidget {
  final String storeId;
  const MenuOverviewScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(dashboardMenuProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Thêm danh mục',
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (categories) => categories.isEmpty
            ? _EmptyMenuPlaceholder(
                onAddCategory: () => _showAddCategoryDialog(context, ref),
              )
            : _MenuList(storeId: storeId, categories: categories),
      ),
      floatingActionButton: menuAsync.hasValue
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Thêm món'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MenuItemFormScreen(storeId: storeId),
                ),
              ).then((_) => ref.invalidate(dashboardMenuProvider(storeId))),
            )
          : null,
    );
  }

  Future<void> _showAddCategoryDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm danh mục'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Tên danh mục'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Thêm')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref.read(menuNotifierProvider.notifier).createCategory(storeId, ctrl.text.trim());
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _EmptyMenuPlaceholder extends StatelessWidget {
  final VoidCallback onAddCategory;
  const _EmptyMenuPlaceholder({required this.onAddCategory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Chưa có danh mục nào', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onAddCategory, child: const Text('Tạo danh mục đầu tiên')),
        ],
      ),
    );
  }
}

class _MenuList extends ConsumerWidget {
  final String storeId;
  final List<MenuCategory> categories;
  const _MenuList({required this.storeId, required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, idx) {
        final cat = categories[idx];
        return _CategorySection(storeId: storeId, category: cat);
      },
    );
  }
}

class _CategorySection extends ConsumerWidget {
  final String storeId;
  final MenuCategory category;
  const _CategorySection({required this.storeId, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${category.items.length} món'),
      initiallyExpanded: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => _editCategoryName(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            onPressed: () => _deleteCategory(context, ref),
          ),
        ],
      ),
      children: category.items.isEmpty
          ? [const ListTile(title: Text('Chưa có món nào', style: TextStyle(color: Colors.grey)))]
          : category.items.map((item) => _MenuItemTile(storeId: storeId, item: item)).toList(),
    );
  }

  Future<void> _editCategoryName(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: category.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi tên danh mục'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await ref
          .read(menuRepositoryProvider)
          .updateCategory(storeId, category.id, name: ctrl.text.trim());
      ref.invalidate(dashboardMenuProvider(storeId));
    }
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: Text('Xoá "${category.name}"? Chỉ xoá được khi không còn món nào.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(menuNotifierProvider.notifier).deleteCategory(storeId, category.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể xoá: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _MenuItemTile extends ConsumerWidget {
  final String storeId;
  final MenuItem item;
  const _MenuItemTile({required this.storeId, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.blue,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.inventory_2, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        // Swipe → quick stock update
        await _showStockDialog(context, ref);
        return false; // không xoá tile
      },
      child: ListTile(
        leading: item.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.thumbnailUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              )
            : const Icon(Icons.fastfood),
        title: Text(item.name),
        subtitle: Text('${_formatPrice(item.price)} đ'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusBadge(item: item),
            Switch(
              value: item.status == 'active',
              onChanged: (_) async {
                await ref
                    .read(menuNotifierProvider.notifier)
                    .toggleStatus(storeId, item.id, item.status);
              },
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MenuItemFormScreen(storeId: storeId, item: item),
          ),
        ).then((_) => ref.invalidate(dashboardMenuProvider(storeId))),
      ),
    );
  }

  Future<void> _showStockDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: item.stock?.toString() ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cập nhật tồn kho: ${item.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'Để trống = không quản lý kho',
            suffixText: 'phần',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (confirmed == true) {
      final val = ctrl.text.trim().isEmpty ? null : int.tryParse(ctrl.text);
      await ref.read(menuNotifierProvider.notifier).updateStock(storeId, item.id, val);
    }
  }

  String _formatPrice(int price) {
    // Định dạng số: 65000 → 65.000
    return price.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MenuItem item;
  const _StatusBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isOutOfStock) {
      return const _Badge(label: 'Hết hàng', color: Colors.red);
    }
    if (item.status == 'paused') {
      return const _Badge(label: 'Tạm ẩn', color: Colors.grey);
    }
    if (item.status == 'closed') {
      return const _Badge(label: 'Đã đóng', color: Colors.brown);
    }
    return const SizedBox.shrink();
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
