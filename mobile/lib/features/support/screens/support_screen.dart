// mobile/lib/features/support/support_screen.dart
// Truy cập: Settings → "Liên hệ hỗ trợ"

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import 'package:dio/dio.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _orderCodeCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _orderCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
      // Đính kèm token từ storage nếu user đã đăng nhập
      // (AuthNotifier inject token qua interceptor — giả sử đã setup ở core)
      await dio.post('/support/tickets', data: {
        'subject': _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        if (_orderCodeCtrl.text.trim().isNotEmpty)
          'relatedOrderCode': _orderCodeCtrl.text.trim(),
      });
      setState(() => _sent = true);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Gửi thất bại')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liên hệ hỗ trợ')),
      body: _sent ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Đã gửi yêu cầu hỗ trợ!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Chúng tôi sẽ phản hồi trong 24h.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề *',
                border: OutlineInputBorder(),
              ),
              maxLength: 200,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập tiêu đề' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Mô tả vấn đề *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              maxLength: 2000,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Nhập mô tả' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _orderCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Mã đơn liên quan (tuỳ chọn)',
                border: OutlineInputBorder(),
                hintText: 'VD: AB251107-456',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Gửi yêu cầu', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
