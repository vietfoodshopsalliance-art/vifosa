// lib/features/order/widgets/refund_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../order_tracking_provider.dart';

class RefundSection extends ConsumerStatefulWidget {
  final OrderDetail order;
  final VoidCallback onRefresh;

  const RefundSection({
    super.key,
    required this.order,
    required this.onRefresh,
  });

  @override
  ConsumerState<RefundSection> createState() => _RefundSectionState();
}

class _RefundSectionState extends ConsumerState<RefundSection> {
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBankInfo() async {
    setState(() => _isSubmitting = true);
    try {
      await DioClient.instance.post(
        '${ApiEndpoints.orders}/${widget.order.id}/refund-bank-info',
        data: {
          'bankName': _bankNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'accountName': _accountNameCtrl.text.trim(),
        },
      );
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmRefund() async {
    try {
      await DioClient.instance
          .post('${ApiEndpoints.orders}/${widget.order.id}/confirm-refund');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _disputeRefund() async {
    try {
      await DioClient.instance
          .post('${ApiEndpoints.orders}/${widget.order.id}/dispute-refund');
      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = widget.order.refundStatus;
    if (rs == null) return const SizedBox.shrink();

    switch (rs) {
      case 'required':
        return _buildRequired();
      case 'submitted':
        return _buildSubmitted();
      case 'refunded':
        return _buildStatusCard(
          icon: Icons.check_circle,
          color: Colors.green,
          text: '✅ Hoàn tiền hoàn tất',
        );
      case 'disputed':
        return _buildStatusCard(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          text: '⚠️ Đang tranh chấp. Admin đang xử lý.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildRequired() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoàn tiền',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          const Text(
              'Đơn bị huỷ. Nhập tài khoản ngân hàng để nhận hoàn tiền.',
              style: TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          _field(_bankNameCtrl, 'Tên ngân hàng'),
          const SizedBox(height: 8),
          _field(_accountNumberCtrl, 'Số tài khoản',
              keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          _field(_accountNameCtrl, 'Tên chủ tài khoản'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitBankInfo,
            style:
                ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: _isSubmitting
                ? const CircularProgressIndicator(strokeWidth: 2)
                : const Text('Gửi thông tin'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitted() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quán đã chuyển khoản hoàn tiền',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (widget.order.refundReceiptUrl != null) ...[
            const Text('Biên lai chuyển khoản:',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                widget.order.refundReceiptUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 60,
                  color: Colors.grey[200],
                  child: const Center(child: Text('Không tải được ảnh')),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmRefund,
                  child: const Text('Đã nhận hoàn tiền'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _disputeRefund,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  child: const Text('Tôi chưa nhận được'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      {required IconData icon,
      required Color color,
      required String text}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );
}
