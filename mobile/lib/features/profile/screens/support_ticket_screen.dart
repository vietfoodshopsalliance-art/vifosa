// lib/features/profile/screens/support_ticket_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../shared/utils/cloudinary_upload.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});

  @override
  State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _orderCodeCtrl = TextEditingController();

  final List<String> _imageUrls = [];
  bool _uploading = false;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _orderCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh')),
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final url = await CloudinaryUpload.uploadImage(
        filePath: file.path,
        folder: 'support',
        transformation: 'w_1200,f_auto,q_auto',
      );
      setState(() => _imageUrls.add(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh thất bại, thử lại')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage(int i) => setState(() => _imageUrls.removeAt(i));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await DioClient.instance.post(ApiEndpoints.supportTickets, data: {
        'subject': _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'images': _imageUrls,
        if (_orderCodeCtrl.text.trim().isNotEmpty)
          'relatedOrderCode': _orderCodeCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi báo cáo. Admin sẽ phản hồi sớm.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gửi thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo lỗi / Đề xuất'),
        actions: [
          TextButton(
            onPressed: (_submitting || _uploading) ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Gửi'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Phản hồi của bạn sẽ được gửi đến team Viet Shops. '
              'Chúng tôi sẽ xem xét và phản hồi qua ứng dụng.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Tiêu đề
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                hintText: 'Vd: Lỗi thanh toán, Đề xuất tính năng...',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập tiêu đề' : null,
            ),
            const SizedBox(height: 12),

            // Nội dung
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Mô tả chi tiết *',
                hintText: 'Mô tả vấn đề bạn gặp phải hoặc đề xuất của bạn...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 5000,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập nội dung' : null,
            ),
            const SizedBox(height: 12),

            // Mã đơn (optional)
            TextFormField(
              controller: _orderCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã đơn liên quan (tuỳ chọn)',
                hintText: 'Vd: AB251107-456',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Ảnh đính kèm
            Row(
              children: [
                const Text('Ảnh đính kèm', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_imageUrls.length}/5', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),

            if (_imageUrls.isNotEmpty)
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imageUrls[i],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: (_uploading || _imageUrls.length >= 5) ? null : _pickImage,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_uploading ? 'Đang tải...' : 'Thêm ảnh'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
