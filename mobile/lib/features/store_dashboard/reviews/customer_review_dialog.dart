// lib/features/store_dashboard/reviews/customer_review_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;

class CustomerReviewDialog extends ConsumerStatefulWidget {
  final Future<void> Function({
    required int stars,
    required String comment,
    required List<String> images,
    required bool isAnonymous,
  }) onSubmit;

  const CustomerReviewDialog({super.key, required this.onSubmit});

  @override
  ConsumerState<CustomerReviewDialog> createState() =>
      _CustomerReviewDialogState();
}

class _CustomerReviewDialogState extends ConsumerState<CustomerReviewDialog> {
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _isAnonymous = false;
  final List<String> _uploadedImageUrls = [];
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_uploadedImageUrls.length >= 3) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final svc = ref.read(imageServiceProvider);
      final result = await svc.uploadFile(
        File(file.path),
        context: ImageUploadContext.review,
      );
      if (mounted) setState(() => _uploadedImageUrls.add(result.url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        stars: _stars,
        comment: _commentCtrl.text.trim(),
        images: _uploadedImageUrls,
        isAnonymous: _isAnonymous,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đánh giá khách hàng'),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stars
            const Text('Số sao', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final active = i < _stars;
                return GestureDetector(
                  onTap: () => setState(() => _stars = i + 1),
                  child: Icon(
                    active ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: active ? Colors.amber : Colors.grey.shade300,
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Comment
            const Text('Nhận xét', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Nhận xét về khách hàng (tuỳ chọn)...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 10),

            // Images
            Row(
              children: [
                const Text('Ảnh', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(width: 6),
                Text('(${_uploadedImageUrls.length}/3)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),
            if (_uploadedImageUrls.isNotEmpty) ...[
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedImageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _uploadedImageUrls[i],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => setState(() => _uploadedImageUrls.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                              ),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (_uploadedImageUrls.length < 3)
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add_a_photo_outlined, size: 16),
                label: Text(_uploading ? 'Đang tải...' : 'Thêm ảnh'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),

            // Anonymous toggle
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v ?? false),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const Text('Đánh giá ẩn danh', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Gửi'),
        ),
      ],
    );
  }
}
