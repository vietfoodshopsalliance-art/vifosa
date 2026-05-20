// lib/features/store_dashboard/menu/screens/menu_overview_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/menu_provider.dart';
import '../../../store/widgets/category_drag_tile.dart' hide CategoryDragTile;
import '../widgets/menu_item_tile.dart';
import 'add_edit_item_screen.dart';
import 'add_edit_category_sheet.dart';

class MenuOverviewScreen extends ConsumerStatefulWidget {
  final String storeId;
  const MenuOverviewScreen({super.key, required this.storeId});

  @override
  ConsumerState<MenuOverviewScreen> createState() => _MenuOverviewScreenState();
}

class _MenuOverviewScreenState extends ConsumerState<MenuOverviewScreen> {
  bool _isReorderMode = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(menuProvider(widget.storeId).notifier).fetchMenu(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuState = ref.watch(menuProvider(widget.storeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Quản lý Menu',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isReorderMode = !_isReorderMode),
            icon: Icon(
              _isReorderMode ? Icons.check_rounded : Icons.swap_vert_rounded,
              size: 18,
              color: _isReorderMode
                  ? const Color(0xFF00C853)
                  : const Color(0xFFFF6B35),
            ),
            label: Text(
              _isReorderMode ? 'Xong' : 'Sắp xếp',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _isReorderMode
                    ? const Color(0xFF00C853)
                    : const Color(0xFFFF6B35),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: menuState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : menuState.error != null
              ? _ErrorView(
                  message: menuState.error!,
                  onRetry: () =>
                      ref.read(menuProvider(widget.storeId).notifier).fetchMenu(),
                )
              : menuState.categories.isEmpty
                  ? _EmptyMenuView(
                      onAddCategory: () => _showAddCategorySheet(context),
                    )
                  : _buildMenuList(context, menuState),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add_item',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditItemScreen(
                  storeId: widget.storeId,
                  categories: menuState.categories,
                ),
              ),
            ),
            backgroundColor: const Color(0xFFFF6B35),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Thêm món',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_category',
            onPressed: () => _showAddCategorySheet(context),
            backgroundColor: Colors.white,
            elevation: 2,
            child: const Icon(Icons.create_new_folder_outlined,
                color: Color(0xFFFF6B35)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(BuildContext context, MenuState menuState) {
    if (_isReorderMode) {
      return ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 140),
        itemCount: menuState.categories.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) newIndex--;
          ref
              .read(menuProvider(widget.storeId).notifier)
              .reorderCategories(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final cat = menuState.categories[index];
          return CategoryDragTile(
            key: ValueKey(cat.id),
            category: cat,
            onEdit: () => _showEditCategorySheet(context, cat),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 140, top: 8),
      itemCount: menuState.categories.length,
      itemBuilder: (context, catIndex) {
        final cat = menuState.categories[catIndex];
        final items = menuState.itemsByCategory[cat.id] ?? [];

        return _CategorySection(
          category: cat,
          items: items,
          storeId: widget.storeId,
          onEditCategory: () => _showEditCategorySheet(context, cat),
          onDeleteCategory: () => _confirmDeleteCategory(context, cat),
          onEditItem: (item) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditItemScreen(
                storeId: widget.storeId,
                categories: menuState.categories,
                item: item,
              ),
            ),
          ),
          onToggleStatus: (item) {
            final newStatus =
                item.status == 'active' ? 'paused' : 'active';
            ref
                .read(menuProvider(widget.storeId).notifier)
                .updateItemStatus(item.id, newStatus);
          },
          onQuickStock: (item) => _showQuickStockSheet(context, item),
        );
      },
    );
  }

  void _showAddCategorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCategorySheet(
        storeId: widget.storeId,
        existingCount: ref.read(menuProvider(widget.storeId)).categories.length,
      ),
    );
  }

  void _showEditCategorySheet(BuildContext context, MenuCategory cat) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditCategorySheet(
        storeId: widget.storeId,
        category: cat,
        existingCount: ref.read(menuProvider(widget.storeId)).categories.length,
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, MenuCategory cat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá danh mục',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
        content: Text(
          'Bạn có chắc muốn xoá danh mục "${cat.name}"? Chỉ xoá được khi không còn món nào trong đó.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(menuProvider(widget.storeId).notifier)
                  .deleteCategory(cat.id);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showQuickStockSheet(BuildContext context, MenuItem item) {
    final controller =
        TextEditingController(text: item.stock?.toString() ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cập nhật tồn kho',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.name,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Số lượng (để trống = không quản lý)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFFFF6B35), width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final val = controller.text.trim();
                      final stock = val.isEmpty ? null : int.tryParse(val);
                      ref
                          .read(menuProvider(widget.storeId).notifier)
                          .updateStock(item.id, stock);
                      Navigator.pop(context);
                    },
                    child: const Text('Lưu',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '* Để trống = không quản lý tồn kho',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Category Section ──────────────────────────────────────────────────────────

class _CategorySection extends StatefulWidget {
  final MenuCategory category;
  final List<MenuItem> items;
  final String storeId;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final void Function(MenuItem) onEditItem;
  final void Function(MenuItem) onToggleStatus;
  final void Function(MenuItem) onQuickStock;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.storeId,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onEditItem,
    required this.onToggleStatus,
    required this.onQuickStock,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Category header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.grid_view_rounded,
                        size: 18, color: Color(0xFFFF6B35)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.name,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          '${widget.items.length} món',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz,
                        color: Color(0xFF999999), size: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'edit') widget.onEditCategory();
                      if (val == 'delete') widget.onDeleteCategory();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Sửa tên', style: TextStyle(fontFamily: 'Nunito')),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Xoá danh mục',
                                style: TextStyle(
                                    fontFamily: 'Nunito', color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...widget.items.map(
              (item) => MenuItemTile(
                item: item,
                onEdit: () => widget.onEditItem(item),
                onToggleStatus: () => widget.onToggleStatus(item),
                onQuickStock: () => widget.onQuickStock(item),
              ),
            ),
            if (widget.items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Chưa có món nào trong danh mục này',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      color: Colors.grey[400],
                      fontSize: 13),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Empty / Error Views ───────────────────────────────────────────────────────

class _EmptyMenuView extends StatelessWidget {
  final VoidCallback onAddCategory;
  const _EmptyMenuView({required this.onAddCategory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu_rounded,
              size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'Menu trống',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy tạo danh mục trước, rồi thêm món vào.',
            style: TextStyle(
                fontFamily: 'Nunito', color: Color(0xFF999999), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Tạo danh mục',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(fontFamily: 'Nunito'),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35)),
            child: const Text('Thử lại',
                style: TextStyle(color: Colors.white, fontFamily: 'Nunito')),
          ),
        ],
      ),
    );
  }
}
