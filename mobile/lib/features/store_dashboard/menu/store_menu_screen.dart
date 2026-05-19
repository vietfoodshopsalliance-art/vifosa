// lib/features/store_dashboard/menu/store_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/store_menu_item.dart';
import 'store_menu_provider.dart';
import 'category_form.dart';
import 'item_form.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

class StoreMenuScreen extends ConsumerWidget {
  final String storeId;
  const StoreMenuScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(storeMenuProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(),
        title: const Text('Quản lý menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(storeMenuProvider(storeId).notifier).fetchMenu(),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Không thể tải menu\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(storeMenuProvider(storeId).notifier).fetchMenu(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (state) => _MenuList(storeId: storeId, state: state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddCategoryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm danh mục'),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        onSave: (name) =>
            ref.read(storeMenuProvider(storeId).notifier).addCategory(name),
      ),
    );
  }
}

class _MenuList extends ConsumerWidget {
  final String storeId;
  final MenuState state;
  const _MenuList({required this.storeId, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_menu_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Chưa có danh mục nào',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Nhấn "+ Thêm danh mục" để bắt đầu'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(storeMenuProvider(storeId).notifier).fetchMenu(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: state.categories.length,
        itemBuilder: (context, index) {
          final cat = state.categories[index];
          return _CategoryTile(storeId: storeId, category: cat);
        },
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final String storeId;
  final StoreCategory category;
  const _CategoryTile({required this.storeId, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(storeMenuProvider(storeId).notifier);

    return ExpansionTile(
      key: PageStorageKey(category.id),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Text(
            '${category.items.length} món',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Sửa danh mục',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => CategoryFormDialog(
                initialName: category.name,
                onSave: (name) =>
                    notifier.updateCategory(category.id, name),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Xoá danh mục',
            onPressed: () => _confirmDelete(context, notifier),
          ),
          const SizedBox(width: 4),
        ],
      ),
      children: [
        ...category.items.map(
          (item) => _ItemTile(storeId: storeId, item: item, category: category),
        ),
        ListTile(
          leading:
              Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          title: Text(
            'Thêm món vào "${category.name}"',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemFormScreen(
                storeId: storeId,
                categoryId: category.id,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, MenuNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá "${category.name}"?'),
        content: const Text('Chỉ xoá được khi không còn món nào trong danh mục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await notifier.deleteCategory(category.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final String storeId;
  final StoreMenuItem item;
  final StoreCategory category;
  const _ItemTile(
      {required this.storeId, required this.item, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(storeMenuProvider(storeId).notifier);
    final isActive = item.status == 'active';
    final isOutOfStock = item.isOutOfStock;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: item.images.isNotEmpty
            ? Image.network(item.images.first,
                width: 50, height: 50, fit: BoxFit.cover)
            : Container(
                width: 50,
                height: 50,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_outlined, color: Colors.grey),
              ),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isActive ? null : Colors.grey,
          decoration:
              item.status == 'closed' ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text('${_currency.format(item.price)} đ',
              style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          if (isOutOfStock)
            const _Badge(label: 'Hết hàng', color: Colors.red)
          else if (item.status == 'paused')
            const _Badge(label: 'Tạm ngưng', color: Colors.orange)
          else if (item.status == 'closed')
            const _Badge(label: 'Đang ẩn', color: Colors.grey),
          if (item.stock != null && !isOutOfStock) ...[
            const SizedBox(width: 6),
            Text('Còn: ${item.stock}',
                style:
                    const TextStyle(fontSize: 11, color: Colors.black54)),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItemFormScreen(
                  storeId: storeId,
                  categoryId: category.id,
                  item: item,
                ),
              ),
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (_) => notifier.toggleItemVisibility(item),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
