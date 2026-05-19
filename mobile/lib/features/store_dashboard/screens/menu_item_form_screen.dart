// mobile/lib/features/store_dashboard/screens/menu_item_form_screen.dart
//
// Dùng cho cả Thêm món (item == null) và Sửa món (item != null).
// Ảnh: client tự upload Cloudinary rồi gửi URL về backend.
// Yêu cầu package: image_picker, cloudinary_public (hoặc tương đương).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/menu_models.dart';
import '../menu/providers/menu_provider.dart';

class MenuItemFormScreen extends ConsumerStatefulWidget {
  final String storeId;
  final MenuItem? item; // null = tạo mới

  const MenuItemFormScreen({super.key, required this.storeId, this.item});

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtr;
  late final TextEditingController _descCtr;
  late final TextEditingController _priceCtr;
  late final TextEditingController _stockCtr;

  String? _selectedCatId;
  String _status = 'active';
  List<String> _images = [];
  bool _saving = false;

  bool get isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtr = TextEditingController(text: item?.name ?? '');
    _descCtr = TextEditingController(text: item?.description ?? '');
    _priceCtr = TextEditingController(text: item != null ? item.price.toString() : '');
    _stockCtr = TextEditingController(text: item?.stock?.toString() ?? '');
    _selectedCatId = item?.categoryId;
    _status = item?.status ?? 'active';
    _images = List.from(item?.images ?? []);
  }

  @override
  void dispose() {
    _nameCtr.dispose();
    _descCtr.dispose();
    _priceCtr.dispose();
    _stockCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(dashboardMenuProvider(widget.storeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa món' : 'Thêm món'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (categories) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Ảnh ──────────────────────────────────────────────────────
              _ImageSection(
                images: _images,
                onAdd: _pickAndUploadImage,
                onDelete: (idx) => setState(() => _images.removeAt(idx)),
              ),
              const SizedBox(height: 20),

              // ── Tên món ──────────────────────────────────────────────────
              TextFormField(
                controller: _nameCtr,
                decoration: const InputDecoration(labelText: 'Tên món *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập tên' : null,
              ),
              const SizedBox(height: 12),

              // ── Mô tả ─────────────────────────────────────────────────────
              TextFormField(
                controller: _descCtr,
                decoration: const InputDecoration(labelText: 'Mô tả'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // ── Giá ──────────────────────────────────────────────────────
              TextFormField(
                controller: _priceCtr,
                decoration: const InputDecoration(labelText: 'Giá (VND) *', suffixText: 'đ'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── Danh mục ─────────────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _selectedCatId,
                decoration: const InputDecoration(labelText: 'Danh mục *'),
                items: categories
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCatId = v),
                validator: (v) => v == null ? 'Chọn danh mục' : null,
              ),
              const SizedBox(height: 12),

              // ── Tồn kho ──────────────────────────────────────────────────
              TextFormField(
                controller: _stockCtr,
                decoration: const InputDecoration(
                  labelText: 'Tồn kho',
                  hintText: 'Để trống = không quản lý',
                  suffixText: 'phần',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // null = không quản lý
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Số nguyên >= 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── Status ───────────────────────────────────────────────────
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Đang bán')),
                  DropdownMenuItem(value: 'paused', child: Text('Tạm ẩn')),
                  DropdownMenuItem(value: 'closed', child: Text('Ngừng bán')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
              ),
              const SizedBox(height: 24),

              // ── Delete (chỉ hiện khi edit) ────────────────────────────────
              if (isEdit)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Xoá món này', style: TextStyle(color: Colors.red)),
                  onPressed: _confirmDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    if (_images.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh')),
      );
      return;
    }
    // TODO: tích hợp image_picker + Cloudinary upload
    // Sau khi upload xong, gọi setState(() => _images.add(cloudinaryUrl));
    //
    // Ví dụ skeleton:
    // final picker = ImagePicker();
    // final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
    // if (file == null) return;
    // final url = await CloudinaryService.upload(file.path, folder: 'menu');
    // setState(() => _images.add(url));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final body = {
        'categoryId': _selectedCatId,
        'name': _nameCtr.text.trim(),
        'description': _descCtr.text.trim(),
        'price': int.parse(_priceCtr.text.trim()),
        'stock': _stockCtr.text.trim().isEmpty ? null : int.parse(_stockCtr.text.trim()),
        'status': _status,
        'images': _images,
      };

      final notifier = ref.read(menuNotifierProvider.notifier);

      if (isEdit) {
        await notifier.updateItem(widget.storeId, widget.item!.id, body);
      } else {
        await notifier.createItem(widget.storeId, body);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá món?'),
        content: const Text('Thao tác này không thể hoàn tác.'),
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
      await ref.read(menuNotifierProvider.notifier).deleteItem(widget.storeId, widget.item!.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

// ── Image section widget ─────────────────────────────────────────────────────

class _ImageSection extends StatelessWidget {
  final List<String> images;
  final VoidCallback onAdd;
  final void Function(int idx) onDelete;

  const _ImageSection({
    required this.images,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ảnh món (${images.length}/5)', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...images.asMap().entries.map((e) => _ImageThumb(
                    url: e.value,
                    onDelete: () => onDelete(e.key),
                  )),
              if (images.length < 5)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        const Text('Ảnh đầu tiên là ảnh chính. Client tự nén ≤ 2000px JPEG 85%.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final String url;
  final VoidCallback onDelete;

  const _ImageThumb({required this.url, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          ),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
