// lib/features/order/widgets/payment_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../order_tracking_provider.dart';

class PaymentSection extends ConsumerWidget {
  final OrderDetail order;
  final bool isGuest;
  final VoidCallback onRefresh;

  const PaymentSection({
    super.key,
    required this.order,
    this.isGuest = false,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = order.paymentStatus;

    switch (ps) {
      case 'unpaid':
        // Only show bank details when awaiting_payment
        if (order.mainStatus == 'awaiting_payment') {
          return _BankTransferCard(order: order, onRefresh: onRefresh);
        }
        return const SizedBox.shrink();

      case 'reported_paid':
        return const _StatusCard(
          icon: Icons.hourglass_top,
          color: Colors.orange,
          text: 'Đang chờ quán xác nhận thanh toán',
          showSpinner: true,
        );

      case 'partial':
        return const _StatusCard(
          icon: Icons.payment,
          color: Colors.blue,
          text: 'Đã thanh toán 50%. Còn lại sẽ thu khi nhận hàng.',
        );

      case 'cod_pending':
        return const _StatusCard(
          icon: Icons.money,
          color: Colors.teal,
          text: 'Thanh toán tiền mặt khi nhận hàng.',
        );

      case 'paid_full':
        return const _StatusCard(
          icon: Icons.check_circle,
          color: Colors.green,
          text: '✅ Đã thanh toán đủ',
        );

      case 'cod_collected':
        return const _StatusCard(
          icon: Icons.check_circle,
          color: Colors.green,
          text: '✅ Đã thu tiền mặt',
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Bank Transfer Card ────────────────────────────────────────────────────────

class _BankTransferCard extends ConsumerWidget {
  final OrderDetail order;
  final VoidCallback onRefresh;

  const _BankTransferCard({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          const Text('Thông tin chuyển khoản',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          if (order.bankName != null)
            _infoRow('Ngân hàng:', order.bankName!),
          if (order.bankAccountNumber != null)
            _infoRow('Số TK:', order.bankAccountNumber!,
                bold: true),
          if (order.bankAccountName != null)
            _infoRow('Chủ TK:', order.bankAccountName!),
          _infoRow('Nội dung CK:', order.code, bold: true),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _confirmPayment(context, ref),
            icon: const Icon(Icons.check),
            label: const Text('Đã chuyển khoản'),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
            ),
          ],
        ),
      );

  Future<void> _confirmPayment(BuildContext context, WidgetRef ref) async {
    try {
      await DioClient.instance
          .post('${ApiEndpoints.orders}/${order.id}/confirm-payment');
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

// ── Generic status card ───────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool showSpinner;

  const _StatusCard({
    required this.icon,
    required this.color,
    required this.text,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ),
          if (showSpinner)
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color)),
        ],
      ),
    );
  }
}
