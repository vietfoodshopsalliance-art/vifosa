// lib/features/store_dashboard/orders/widgets/order_card_store.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/store_order.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

class OrderCardStore extends StatefulWidget {
  final StoreOrder order;
  final bool showTimer;
  final bool compact;
  final bool greyed;
  final Widget? actionRow;
  final Widget? extraContent;

  const OrderCardStore({
    super.key,
    required this.order,
    this.showTimer = false,
    this.compact = false,
    this.greyed = false,
    this.actionRow,
    this.extraContent,
  });

  @override
  State<OrderCardStore> createState() => _OrderCardStoreState();
}

class _OrderCardStoreState extends State<OrderCardStore> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.showTimer && widget.order.pendingAt != null) {
      _calcRemaining();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) _calcRemaining();
      });
    }
  }

  void _calcRemaining() {
    final deadline =
        widget.order.pendingAt!.add(const Duration(minutes: 15));
    final diff = deadline.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timerText {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _isUrgent => _remaining.inSeconds < 180;

  String _deliveryMethodLabel(String method) {
    switch (method) {
      case 'A':
        return '🛵 Quán giao';
      case 'B':
        return '🚶 Tự đến';
      case 'C':
        return '🚚 Shipper riêng';
      default:
        return method;
    }
  }

  String _paymentLabel(String status) {
    const map = {
      'pending': 'Chờ thanh toán',
      'reported_paid': 'Khách báo đã trả',
      'cod_pending': 'COD – chưa thu',
      'cod_collected': 'COD – đã thu',
      'paid_full': 'Đã thanh toán',
      'partial': 'Đã trả một phần',
    };
    return map[status] ?? status;
  }

  Color _paymentColor(String status) {
    if (status == 'paid_full' || status == 'cod_collected') {
      return Colors.green;
    }
    if (status == 'reported_paid') return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final cardColor = widget.greyed
        ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${order.code}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (widget.showTimer)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isUrgent
                          ? Colors.red.withOpacity(0.12)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _timerText,
                      style: TextStyle(
                        color: _isUrgent ? Colors.red : Colors.blue.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                if (widget.greyed)
                  Text(
                    'Đã hoàn tất lúc: ${DateFormat('HH:mm dd/MM/yyyy').format(order.createdAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Payment status badge
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _paymentColor(order.paymentStatus)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _paymentLabel(order.paymentStatus),
                    style: TextStyle(
                      fontSize: 11,
                      color: _paymentColor(order.paymentStatus),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _deliveryMethodLabel(order.deliveryMethod),
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),

            if (!widget.compact) ...[
              const Divider(height: 16),
              // Items
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('${item.name}  x${item.quantity}')),
                        Text(
                          '${_currency.format(item.price * item.quantity)} đ',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Phí ship:'),
                  Text('${_currency.format(order.shipFee)} đ'),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng:',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${_currency.format(order.total)} đ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddressText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (order.note != null && order.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.notes, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '"${order.note}"',
                        style: const TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ],

            if (widget.extraContent != null) ...[
              const Divider(height: 16),
              widget.extraContent!,
            ],

            if (widget.actionRow != null) ...[
              const SizedBox(height: 12),
              widget.actionRow!,
            ],
          ],
        ),
      ),
    );
  }
}
