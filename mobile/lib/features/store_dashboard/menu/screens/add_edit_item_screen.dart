// lib/features/store_dashboard/menu/screens/add_edit_item_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/menu_provider.dart';
import '../../../store/providers/item_form_provider.dart';

class AddEditItemScreen extends ConsumerStatefulWidget {
  final String storeId;
  final List<MenuCategory> categories;
  final MenuItem? item; // null = thêm mới

  const AddEditItemScreen({
    super.key,
    required this.storeId,
    required this.categories,
    this.item,
  });

  @override
  ConsumerState<AddEditItemScreen> createState() => _AddEditItemScreenState();
}

class _AddEditItemScreenState extends ConsumerState<AddEditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  String? _selectedCategoryId;
  String _status = 'active';
  bool _manageStock = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameCtrl.text = item.name;
      _descCtrl.text = item.description ?? '';
      _priceCtrl.text = item.price.toString();
      _selectedCategoryId = item.categoryId;
      _status = item.status;
      _manageStock = item.stock != null;
      if (item.stock != null) _stockCtrl.text = item.stock.toString();
    } else if (widget.categories.isNotEmpty) {
      _selectedCategoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  bool get isEditing => widget.item != null;

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(itemFormProvider(widget.item?.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isEditing ? 'Sửa món' : 'Thêm món mới',
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Ảnh món ────────────────────────────────────
            _ImageSection(
              storeId: widget.storeId,
              itemId: widget.item?.id,
              images: formState.images,
            ),
            const SizedBox(height: 16),

            // ── Thông tin cơ bản ───────────────────────────
            _SectionCard(
              title: 'Thông tin cơ bản',
              children: [
                _FormField(
                  label: 'Tên món *',
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDeco('Vd: Phở bò tái'),
                    style: _inputStyle,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên món' : null,
                  ),
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Mô tả',
                  child: TextFormField(
                    controller: _descCtrl,
                    decoration: _inputDeco('Mô tả ngắn về món...'),
                    style: _inputStyle,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                _FormField(
                  label: 'Danh mục *',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: _inputDeco('Chọn danh mục'),
                    style: _inputStyle.copyWith(color: const Color(0xFF1A1A1A)),
                    items: widget.categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name,
                                  style: const TextStyle(fontFamily: 'Nunito')),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) =>
                        v == null ? 'Chọn một danh mục' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Giá ───────────────────────────────────────
            _SectionCard(
              title: 'Giá bán',
              children: [
                _FormField(
                  label: 'Giá (VND) *',
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: _inputDeco('Vd: 65000').copyWith(
                      suffixText: '₫',
                      suffixStyle: const TextStyle(
                          fontFamily: 'Nunito',
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w700),
                    ),
                    style: _inputStyle,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập giá';
                      if (int.tryParse(v) == null) return 'Giá không hợp lệ';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Tồn kho ───────────────────────────────────
            _SectionCard(
              title: 'Tồn kho',
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quản lý tồn kho',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Switch(
                      value: _manageStock,
                      activeThumbColor: const Color(0xFFFF6B35),
                      onChanged: (v) => setState(() {
                        _manageStock = v;
                        if (!v) _stockCtrl.clear();
                      }),
                    ),
                  ],
                ),
                if (_manageStock) ...[
                  const SizedBox(height: 12),
                  _FormField(
                    label: 'Số lượng còn lại',
                    child: TextFormField(
                      controller: _stockCtrl,
                      decoration: _inputDeco('0'),
                      style: _inputStyle,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (_manageStock &&
                            (v == null || v.isEmpty || int.tryParse(v) == null)) {
                          return 'Nhập số lượng hợp lệ';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _InfoBox(
                    icon: Icons.info_outline,
                    text:
                        'Khi tồn kho = 0, món sẽ tự ẩn khỏi menu khách. Đặt null để không quản lý.',
                  ),
                ],
                if (!_manageStock)
                  const _InfoBox(
                    icon: Icons.all_inclusive_rounded,
                    text: 'Món luôn hiển thị, không giới hạn số lượng.',
                    color: Color(0xFF00C853),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Trạng thái ────────────────────────────────
            _SectionCard(
              title: 'Trạng thái',
              children: [
                ...[
                  (
                    'active',
                    'Đang bán',
                    'Hiển thị và cho đặt hàng',
                    const Color(0xFF00C853)
                  ),
                  (
                    'paused',
                    'Tạm ẩn',
                    'Ẩn tạm thời, sẽ bán lại sau',
                    const Color(0xFFFF9800)
                  ),
                  (
                    'closed',
                    'Ngừng bán',
                    'Ẩn vĩnh viễn khỏi menu khách',
                    const Color(0xFF9E9E9E)
                  ),
                ].map(
                  (option) => _StatusOption(
                    value: option.$1,
                    label: option.$2,
                    hint: option.$3,
                    color: option.$4,
                    selected: _status == option.$1,
                    onTap: () => setState(() => _status = option.$1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Nút lưu ───────────────────────────────────
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? 'Lưu thay đổi' : 'Thêm món',
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final notifier = ref.read(menuProvider(widget.storeId).notifier);
    final payload = MenuItemPayload(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      price: int.parse(_priceCtrl.text),
      categoryId: _selectedCategoryId!,
      status: _status,
      stock: _manageStock ? int.parse(_stockCtrl.text) : null,
    );

    final success = isEditing
        ? await notifier.updateItem(widget.item!.id, payload)
        : await notifier.addItem(payload);

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu thất bại. Vui lòng thử lại.',
                style: TextStyle(fontFamily: 'Nunito')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá món',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
        content: Text(
          'Bạn có chắc muốn xoá "${widget.item!.name}"?',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(menuProvider(widget.storeId).notifier)
                  .deleteItem(widget.item!.id);
              if (mounted && success) Navigator.pop(context);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontFamily: 'Nunito', color: Color(0xFFBBBBBB), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFF6B35), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
      );

  TextStyle get _inputStyle => const TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.w500,
        fontSize: 15,
        color: Color(0xFF1A1A1A),
      );
}

// ─── Image Section ─────────────────────────────────────────────────────────────

class _ImageSection extends ConsumerWidget {
  final String storeId;
  final String? itemId;
  final List<String> images;

  const _ImageSection({
    required this.storeId,
    this.itemId,
    required this.images,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Ảnh món ăn',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '${images.length}/5',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Color(0xFF999999),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...images.asMap().entries.map((e) {
                  final index = e.key;
                  final url = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            '$url?tx=w_200,f_auto,q_auto',
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                        if (index == 0)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Chính',
                                  style: TextStyle(
                                      fontFamily: 'Nunito',
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _deleteImage(context, ref, index),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (images.length < 5)
                  GestureDetector(
                    onTap: () => _pickImage(context, ref),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: const Color(0xFFE0E0E0), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFF9F9F9),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              color: Color(0xFFFF6B35), size: 28),
                          SizedBox(height: 4),
                          Text('Thêm ảnh',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                color: Color(0xFF999999),
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '* Ảnh đầu tiên là ảnh chính. Client tự nén trước upload.',
            style: TextStyle(
                fontFamily: 'Nunito', fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (itemId != null) {
      await ref
          .read(itemFormProvider(itemId).notifier)
          .uploadImage(File(picked.path));
    } else {
      // Khi tạo mới, lưu file tạm, upload sau khi có itemId
      ref.read(itemFormProvider(null).notifier).addPendingImage(File(picked.path));
    }
  }

  void _deleteImage(BuildContext context, WidgetRef ref, int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: const Text('Xoá ảnh này?',
            style: TextStyle(fontFamily: 'Nunito')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(itemFormProvider(itemId).notifier)
                  .deleteImage(index);
            },
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF555555))),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String value;
  final String label;
  final String hint;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.value,
    required this.label,
    required this.hint,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xFFE0E0E0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                    color: selected ? color : const Color(0xFFCCCCCC), width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          color: selected ? color : const Color(0xFF1A1A1A))),
                  Text(hint,
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Color(0xFF999999))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBox({
    required this.icon,
    required this.text,
    this.color = const Color(0xFFFF9800),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }
}
