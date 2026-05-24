// mobile/lib/features/reviews/screens/review_form_screen.dart
//
// Được mở từ order tracking screen sau khi đơn delivered.
// Nhận: orderId, storeId, orderCode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../review_providers.dart';

class ReviewFormScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String orderCode;

  const ReviewFormScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
  });

  @override
  ConsumerState<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends ConsumerState<ReviewFormScreen> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _isAnonymous = false;
  final List<String> _uploadedImageUrls = []; // URLs sau khi upload Cloudinary
  bool _loading = false;

  // Upload ảnh lên Cloudinary (client-side) rồi lấy URL
  Future<void> _pickAndUploadImage() async {
    if (_uploadedImageUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 3 ảnh')),
      );
      return;
    }
    // TODO: implement Cloudinary direct upload
    // final picker = ImagePicker();
    // final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    // if (xfile == null) return;
    // final url = await CloudinaryService.upload(xfile);
    // setState(() => _uploadedImageUrls.add(url));
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn số sao')),
      );
      return;
    }
    if (_commentCtrl.text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bình luận tối đa 500 ký tự')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      await repo.createReview(
        orderId: widget.orderId,
        stars: _stars,
        comment: _commentCtrl.text.trim(),
        images: _uploadedImageUrls,
        isAnonymous: _isAnonymous,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đánh giá thành công!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Đánh giá đơn ${widget.orderCode}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Star picker ────────────────────────────────────────────
            const Text('Chọn số sao', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _stars = star),
                  child: Icon(
                    _stars >= star ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // ── Comment ────────────────────────────────────────────────
            const Text('Bình luận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Chia sẻ cảm nhận của bạn...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // ── Ảnh ───────────────────────────────────────────────────
            const Text('Ảnh (tối đa 3)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._uploadedImageUrls.map((url) => Stack(
                      children: [
                        Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                        Positioned(
                          top: 0, right: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _uploadedImageUrls.remove(url)),
                            child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                          ),
                        ),
                      ],
                    )),
                if (_uploadedImageUrls.length < 3)
                  GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add_a_photo, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Anonymous toggle ───────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đánh giá ẩn danh'),
              value: _isAnonymous,
              onChanged: (v) => setState(() => _isAnonymous = v),
            ),
            const SizedBox(height: 24),

            // ── Submit ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Gửi đánh giá', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }
}