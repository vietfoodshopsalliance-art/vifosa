// lib/features/home/screens/support_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _category = 'order';
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subjectCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await DioClient.instance.post(ApiEndpoints.supportTickets, data: {
        'category': _category,
        'subject': _subjectCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      });
      setState(() => _submitted = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỗ trợ')),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 72),
            SizedBox(height: 16),
            Text(
              'Yêu cầu đã gửi!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Chúng tôi sẽ phản hồi trong vòng 24 giờ. Cảm ơn bạn đã liên hệ.',
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // FAQ cards
          const Text('Câu hỏi thường gặp', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _FaqCard(
            question: 'Làm sao để hủy đơn hàng?',
            answer: 'Bạn có thể hủy đơn khi đơn còn ở trạng thái "Chờ xác nhận". Vào chi tiết đơn hàng và nhấn "Hủy đơn".',
          ),
          _FaqCard(
            question: 'Tôi chuyển khoản rồi nhưng đơn chưa cập nhật?',
            answer: 'Sau khi chuyển khoản, nhấn "Xác nhận đã chuyển khoản" trong chi tiết đơn. Cửa hàng sẽ kiểm tra và xác nhận.',
          ),
          _FaqCard(
            question: 'Làm sao để yêu cầu hoàn tiền?',
            answer: 'Nếu hàng không nhận được hoặc sai hàng, chọn "Yêu cầu hoàn tiền" trong chi tiết đơn và điền thông tin tài khoản ngân hàng.',
          ),
          const SizedBox(height: 24),

          // Contact form
          const Text('Gửi yêu cầu hỗ trợ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'order', child: Text('Vấn đề đơn hàng')),
              DropdownMenuItem(value: 'payment', child: Text('Thanh toán / Hoàn tiền')),
              DropdownMenuItem(value: 'account', child: Text('Tài khoản')),
              DropdownMenuItem(value: 'other', child: Text('Khác')),
            ],
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectCtrl,
            decoration: const InputDecoration(
              labelText: 'Tiêu đề',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Mô tả chi tiết vấn đề',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Gửi yêu cầu',
            onPressed: _loading ? null : _submit,
            isLoading: _loading,
            variant: ButtonVariant.primary,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqCard({required this.question, required this.answer});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(widget.answer, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}