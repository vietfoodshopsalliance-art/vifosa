// lib/features/store_dashboard/screens/store_menu.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/image_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class MenuCategoryModel {
  final String id;
  final String name;
  final int sortOrder;
  final List<MenuItemModel> items;

  const MenuCategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.items,
  });

  factory MenuCategoryModel.fromJson(
    Map<String, dynamic> j, {
    List<MenuItemModel> items = const [],
  }) =>
      MenuCategoryModel(
        id: (j['_id'] ?? '').toString(),
        name: j['name'] as String? ?? '',
        sortOrder: j['displayOrder'] as int? ?? 0,
        items: items,
      );
}

class MenuItemModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable; // status == 'active'
  final String status;    // 'active' | 'closed' | 'paused'
  final String categoryId;
  final int? stock;       // null = vô hạn

  const MenuItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    required this.status,
    required this.categoryId,
    this.stock,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> j) {
    final images = (j['images'] as List?)?.cast<String>() ?? [];
    final status = j['status'] as String? ?? 'active';
    return MenuItemModel(
      id: (j['_id'] ?? '').toString(),
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      price: (j['price'] as num? ?? 0).toDouble(),
      imageUrl: images.isNotEmpty ? images.first : null,
      isAvailable: status == 'active',
      status: status,
      categoryId: (j['categoryId'] ?? '').toString(),
      stock: j['stock'] as int?,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final storeMenuProvider = StateNotifierProvider.family<StoreMenuNotifier,
    StoreMenuState, String>(
  (ref, storeId) => StoreMenuNotifier(storeId),
);

class StoreMenuState {
  final List<MenuCategoryModel> categories;
  final bool isLoading;
  final String? error;

  const StoreMenuState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  StoreMenuState copyWith({
    List<MenuCategoryModel>? categories,
    bool? isLoading,
    String? error,
  }) =>
      StoreMenuState(
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class StoreMenuNotifier extends StateNotifier<StoreMenuState> {
  final String storeId;

  StoreMenuNotifier(this.storeId) : super(const StoreMenuState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Dùng /menu/all để chủ quán thấy cả món bị paused
      final res =
          await DioClient.instance.get(ApiEndpoints.storeMenuAll(storeId));
      final data = res.data as Map<String, dynamic>;

      final rawItems = (data['items'] as List? ?? []);
      final itemsByCat = <String, List<MenuItemModel>>{};
      for (final raw in rawItems) {
        final item = MenuItemModel.fromJson(raw as Map<String, dynamic>);
        itemsByCat.putIfAbsent(item.categoryId, () => []).add(item);
      }

      final cats = (data['categories'] as List? ?? []).map((e) {
        final catJson = e as Map<String, dynamic>;
        final catId = (catJson['_id'] ?? '').toString();
        return MenuCategoryModel.fromJson(
          catJson,
          items: itemsByCat[catId] ?? [],
        );
      }).toList();

      state = state.copyWith(categories: cats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<void> toggleItemAvailability(String itemId, bool current) async {
    try {
      await DioClient.instance.patch(
        ApiEndpoints.storeItemById(storeId, itemId),
        data: {'status': current ? 'closed' : 'active'},
      );
      await _load();
    } catch (_) {}
  }

  Future<void> adjustItemStock(String itemId, int? newStock) async {
    try {
      await DioClient.instance.patch(
        ApiEndpoints.storeItemById(storeId, itemId),
        data: {'stock': newStock},
      );
      await _load();
    } catch (_) {}
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await DioClient.instance
          .delete(ApiEndpoints.storeItemById(storeId, itemId));
      await _load();
    } catch (_) {}
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await DioClient.instance
          .delete(ApiEndpoints.storeCategoryById(storeId, categoryId));
      await _load();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StoreMenuScreen extends ConsumerWidget {
  final String storeId;
  const StoreMenuScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeMenuProvider(storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý menu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(storeMenuProvider(storeId).notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'add_category',
            onPressed: () =>
                _showCategoryDialog(context, ref, storeId, null),
            tooltip: 'Thêm danh mục',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_item',
            onPressed: state.categories.isNotEmpty
                ? () => _showItemDialog(context, ref, storeId, null,
                    state.categories)
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Thêm món'),
            backgroundColor: AppTheme.primary,
          ),
        ],
      ),
      body: state.isLoading && state.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(state.error!))
              : state.categories.isEmpty
                  ? _EmptyMenuView(
                      onAddCategory: () =>
                          _showCategoryDialog(context, ref, storeId, null),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(storeMenuProvider(storeId).notifier)
                          .refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(
                            left: 16, right: 16, top: 12, bottom: 80),
                        itemCount: state.categories.length,
                        itemBuilder: (context, i) => _CategorySection(
                          category: state.categories[i],
                          storeId: storeId,
                          onEditCategory: () => _showCategoryDialog(
                              context, ref, storeId, state.categories[i]),
                          onDeleteCategory: () => _confirmDeleteCategory(
                              context, ref, storeId, state.categories[i].id),
                          onAddItem: () => _showItemDialog(
                              context, ref, storeId, null, state.categories,
                              defaultCategoryId: state.categories[i].id),
                          onEditItem: (item) => _showItemDialog(
                              context, ref, storeId, item, state.categories),
                          onToggleItem: (item) => ref
                              .read(storeMenuProvider(storeId).notifier)
                              .toggleItemAvailability(
                                  item.id, item.isAvailable),
                          onAdjustStock: (item) =>
                              _showStockDialog(context, ref, storeId, item),
                          onDeleteItem: (item) => _confirmDeleteItem(
                              context, ref, storeId, item.id),
                        ),
                      ),
                    ),
    );
  }

  void _showCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    MenuCategoryModel? existing,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _CategoryDialog(
        storeId: storeId,
        existing: existing,
        onSaved: () {
          Navigator.pop(ctx);
          ref.read(storeMenuProvider(storeId).notifier).refresh();
        },
      ),
    );
  }

  void _showItemDialog(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    MenuItemModel? existing,
    List<MenuCategoryModel> categories, {
    String? defaultCategoryId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ItemFormSheet(
        storeId: storeId,
        existing: existing,
        categories: categories,
        defaultCategoryId: defaultCategoryId,
        onSaved: () {
          Navigator.pop(ctx);
          ref.read(storeMenuProvider(storeId).notifier).refresh();
        },
      ),
    );
  }

  void _showStockDialog(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    MenuItemModel item,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _StockAdjustDialog(
        storeId: storeId,
        item: item,
        onSaved: () {
          Navigator.pop(ctx);
          ref.read(storeMenuProvider(storeId).notifier).refresh();
        },
      ),
    );
  }

  void _confirmDeleteCategory(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    String categoryId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: const Text('Tất cả món trong danh mục cũng sẽ bị xoá.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(storeMenuProvider(storeId).notifier)
                  .deleteCategory(categoryId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    String itemId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá món này?'),
        content: const Text('Thao tác không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(storeMenuProvider(storeId).notifier)
                  .deleteItem(itemId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Section
// ---------------------------------------------------------------------------

class _CategorySection extends StatelessWidget {
  final MenuCategoryModel category;
  final String storeId;
  final VoidCallback onEditCategory;
  final VoidCallback onDeleteCategory;
  final VoidCallback onAddItem;
  final void Function(MenuItemModel) onEditItem;
  final void Function(MenuItemModel) onToggleItem;
  final void Function(MenuItemModel) onAdjustStock;
  final void Function(MenuItemModel) onDeleteItem;

  const _CategorySection({
    required this.category,
    required this.storeId,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onAddItem,
    required this.onEditItem,
    required this.onToggleItem,
    required this.onAdjustStock,
    required this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header danh mục
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.green, size: 20),
                onPressed: onAddItem,
                tooltip: 'Thêm món',
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEditCategory,
                tooltip: 'Sửa tên',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                onPressed: onDeleteCategory,
                tooltip: 'Xoá danh mục',
              ),
            ],
          ),
        ),

        if (category.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Chưa có món. Nhấn + để thêm.',
              style: TextStyle(
                  color: Colors.grey.shade400, fontStyle: FontStyle.italic),
            ),
          )
        else
          ...category.items.map(
            (item) => _MenuItemTile(
              item: item,
              onEdit: () => onEditItem(item),
              onToggle: () => onToggleItem(item),
              onAdjustStock: () => onAdjustStock(item),
              onDelete: () => onDeleteItem(item),
            ),
          ),

        const Divider(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Menu Item Tile
// ---------------------------------------------------------------------------

class _MenuItemTile extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onAdjustStock;
  final VoidCallback onDelete;

  const _MenuItemTile({
    required this.item,
    required this.onEdit,
    required this.onToggle,
    required this.onAdjustStock,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'vi_VN');

    return Opacity(
      opacity: item.isAvailable ? 1.0 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: item.imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 52,
                    height: 52,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.fastfood_outlined,
                        color: Colors.grey),
                  ),
          ),
          title: Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description != null && item.description!.isNotEmpty)
                Text(
                  item.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              Row(
                children: [
                  Text(
                    '${formatter.format(item.price)}đ',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (item.stock != null) ...[
                    const SizedBox(width: 8),
                    _StockChip(stock: item.stock!),
                  ],
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: item.isAvailable,
                onChanged: (_) => onToggle(),
                activeThumbColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'stock') onAdjustStock();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa món')),
                  PopupMenuItem(
                    value: 'stock',
                    child: Text('Tồn kho'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Xoá', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Chip
// ---------------------------------------------------------------------------

class _StockChip extends StatelessWidget {
  final int stock;
  const _StockChip({required this.stock});

  @override
  Widget build(BuildContext context) {
    final isEmpty = stock == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEmpty ? Colors.red.shade200 : Colors.green.shade200,
        ),
      ),
      child: Text(
        isEmpty ? 'Hết hàng' : 'Còn $stock',
        style: TextStyle(
          fontSize: 11,
          color:
              isEmpty ? Colors.red.shade700 : Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stock Adjust Dialog
// ---------------------------------------------------------------------------

class _StockAdjustDialog extends StatefulWidget {
  final String storeId;
  final MenuItemModel item;
  final VoidCallback onSaved;

  const _StockAdjustDialog({
    required this.storeId,
    required this.item,
    required this.onSaved,
  });

  @override
  State<_StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<_StockAdjustDialog> {
  late bool _trackStock;
  late final TextEditingController _stockCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _trackStock = widget.item.stock != null;
    _stockCtrl = TextEditingController(
      text: widget.item.stock?.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newStock = _trackStock
          ? (int.tryParse(_stockCtrl.text.trim()) ?? 0)
          : null;
      await DioClient.instance.patch(
        ApiEndpoints.storeItemById(widget.storeId, widget.item.id),
        data: {'stock': newStock},
      );
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Tồn kho',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.name,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Theo dõi tồn kho'),
            subtitle: const Text('Tắt = bán vô hạn'),
            value: _trackStock,
            onChanged: (v) => setState(() => _trackStock = v),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.primary,
          ),
          if (_trackStock) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Số lượng còn lại',
                border: OutlineInputBorder(),
                suffixText: 'phần',
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Bán không giới hạn số lượng.',
                style:
                    TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        AppButton(
          label: 'Lưu',
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          variant: ButtonVariant.primary,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category Dialog
// ---------------------------------------------------------------------------

class _CategoryDialog extends StatefulWidget {
  final String storeId;
  final MenuCategoryModel? existing;
  final VoidCallback onSaved;

  const _CategoryDialog({
    required this.storeId,
    this.existing,
    required this.onSaved,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      if (widget.existing != null) {
        await DioClient.instance.patch(
          ApiEndpoints.storeCategoryById(
              widget.storeId, widget.existing!.id),
          data: {'name': _nameCtrl.text.trim()},
        );
      } else {
        await DioClient.instance.post(
          ApiEndpoints.storeCategories(widget.storeId),
          data: {'name': _nameCtrl.text.trim()},
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.existing != null ? 'Sửa danh mục' : 'Thêm danh mục'),
      content: TextField(
        controller: _nameCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Tên danh mục',
          hintText: 'VD: Món chính, Tráng miệng...',
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ')),
        AppButton(
          label: widget.existing != null ? 'Lưu' : 'Thêm',
          onPressed: _saving ? null : _save,
          isLoading: _saving,
          variant: ButtonVariant.primary,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Item Form Sheet
// ---------------------------------------------------------------------------

class _ItemFormSheet extends StatefulWidget {
  final String storeId;
  final MenuItemModel? existing;
  final List<MenuCategoryModel> categories;
  final String? defaultCategoryId;
  final VoidCallback onSaved;

  const _ItemFormSheet({
    required this.storeId,
    this.existing,
    required this.categories,
    this.defaultCategoryId,
    required this.onSaved,
  });

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String? _selectedCategoryId;
  XFile? _imageFile;
  String? _existingImageUrl;
  bool _trackStock = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _priceCtrl.text = e.price.toStringAsFixed(0);
      _descCtrl.text = e.description ?? '';
      _selectedCategoryId = e.categoryId;
      _existingImageUrl = e.imageUrl;
      _trackStock = e.stock != null;
      _stockCtrl.text = e.stock?.toString() ?? '0';
    } else {
      _selectedCategoryId =
          widget.defaultCategoryId ?? widget.categories.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImageService.instance.pickSingle();
    if (file == null) return;
    setState(() => _imageFile = file);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      String? newImageUrl;
      if (_imageFile != null) {
        final uploaded = await ImageService.instance.uploadXFile(
          _imageFile!,
          context: ImageUploadContext.menuItem,
        );
        newImageUrl = uploaded.url;
      }

      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
        'description': _descCtrl.text.trim(),
        'categoryId': _selectedCategoryId,
        if (newImageUrl != null) 'images': [newImageUrl],
        'stock': _trackStock
            ? (int.tryParse(_stockCtrl.text.trim()) ?? 0)
            : null,
      };

      if (widget.existing != null) {
        await DioClient.instance.patch(
          ApiEndpoints.storeItemById(
              widget.storeId, widget.existing!.id),
          data: data,
        );
      } else {
        await DioClient.instance
            .post(ApiEndpoints.storeItems(widget.storeId), data: data);
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing != null ? 'Sửa món' : 'Thêm món mới',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(_imageFile!.path),
                            fit: BoxFit.cover),
                      )
                    : _existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: _existingImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 32, color: Colors.grey),
                              SizedBox(height: 6),
                              Text('Thêm ảnh món',
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên món *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá (đ) *',
                border: OutlineInputBorder(),
                suffixText: 'đ',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Danh mục *',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: 4),

            // ── Tồn kho ───────────────────────────────────────────────────
            SwitchListTile(
              title: const Text('Theo dõi tồn kho'),
              subtitle: const Text('Tắt = bán vô hạn'),
              value: _trackStock,
              onChanged: (v) => setState(() => _trackStock = v),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppTheme.primary,
            ),
            if (_trackStock) ...[
              TextField(
                controller: _stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng tồn kho',
                  border: OutlineInputBorder(),
                  suffixText: 'phần',
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: widget.existing != null ? 'Lưu thay đổi' : 'Thêm món',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                variant: ButtonVariant.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty Menu View
// ---------------------------------------------------------------------------

class _EmptyMenuView extends StatelessWidget {
  final VoidCallback onAddCategory;
  const _EmptyMenuView({required this.onAddCategory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Menu trống',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Hãy tạo danh mục trước, rồi thêm món vào',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAddCategory,
            icon: const Icon(Icons.add),
            label: const Text('Tạo danh mục đầu tiên'),
          ),
        ],
      ),
    );
  }
}
