// lib/features/order/widgets/order_stepper.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../order_tracking_provider.dart';

class OrderStepperWidget extends StatefulWidget {
  final OrderDetail order;
  final int pendingTimeoutMinutes; // from store settings, default 15

  const OrderStepperWidget({
    super.key,
    required this.order,
    this.pendingTimeoutMinutes = 15,
  });

  @override
  State<OrderStepperWidget> createState() => _OrderStepperWidgetState();
}

class _OrderStepperWidgetState extends State<OrderStepperWidget> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.order.mainStatus == 'pending_store' &&
        widget.order.pendingAt != null) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(OrderStepperWidget old) {
    super.didUpdateWidget(old);
    if (widget.order.mainStatus == 'pending_store' &&
        widget.order.pendingAt != null) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    final pendingAt = DateTime.tryParse(widget.order.pendingAt!);
    if (pendingAt == null) return;
    final deadline =
        pendingAt.add(Duration(minutes: widget.pendingTimeoutMinutes));
    _tick(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(deadline));
  }

  void _tick(DateTime deadline) {
    final now = DateTime.now();
    final remaining = deadline.difference(now);
    if (mounted) {
      setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
    }
  }

  // ─── Step logic ────────────────────────────────────────────────────────────

  static const _allSteps = [
    'Đã đặt',
    'Chờ quán nhận',
    'Đang chuẩn bị',
    'Đang giao',
    'Đã giao',
    'Hoàn tất',
  ];

  int _currentIndex(String status) {
    switch (status) {
      case 'created':
        return 0;
      case 'awaiting_payment':
      case 'awaiting_store_open':
      case 'pending_store':
        return 1;
      case 'preparing':
        return 2;
      case 'delivering':
        return 3;
      case 'delivered':
        return 4;
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }

  String? _subText(String status) {
    switch (status) {
      case 'awaiting_payment':
        return 'Chờ xác nhận thanh toán';
      case 'awaiting_store_open':
        return 'Đơn đặt trước — quán chưa mở';
      case 'pending_store':
        if (_remaining == Duration.zero) return 'Đang xử lý huỷ tự động...';
        final mm = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final ss = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        return 'Quán cần xác nhận trong $mm:$ss';
      default:
        return null;
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = widget.order.mainStatus;
    final isCancelled = status == 'cancelled';
    final isDeliveryA = widget.order.deliveryMethod == 'A';
    final current = _currentIndex(status);
    final sub = _subText(status);

    // Hide "Đang giao" if not delivery method A
    final steps = isDeliveryA
        ? _allSteps
        : _allSteps.where((s) => s != 'Đang giao').toList();

    final activeColor = isCancelled ? Colors.red : Theme.of(context).colorScheme.primary;
    final inactiveColor = Colors.grey[300]!;

    return Column(
      children: [
        if (isCancelled)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 18),
                    SizedBox(width: 6),
                    Text('Đơn đã bị huỷ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                if (widget.order.cancelInfo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                      'Lý do: ${widget.order.cancelInfo!.reason}',
                      style: const TextStyle(fontSize: 13)),
                  Text(
                      'Huỷ bởi: ${_cancelledByLabel(widget.order.cancelInfo!.cancelledBy)}',
                      style: const TextStyle(fontSize: 13)),
                  Text(
                      'Thời gian: ${widget.order.cancelInfo!.at}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),

        // Stepper row
        Row(
          children: List.generate(steps.length, (i) {
            final adjustedCurrent =
                isDeliveryA ? current : (current >= 3 ? current - 1 : current);
            final isDone = i <= adjustedCurrent;
            final isActive = i == adjustedCurrent;

            return Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isDone ? activeColor : inactiveColor,
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone ? activeColor : inactiveColor,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : Text('${i + 1}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.white)),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i < adjustedCurrent ? activeColor : inactiveColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isDone ? activeColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        // Sub text (countdown / note)
        if (sub != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Text(
              sub,
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        ],
      ],
    );
  }

  String _cancelledByLabel(String by) {
    switch (by) {
      case 'customer':
        return 'Khách';
      case 'store':
        return 'Quán';
      case 'system':
        return 'Hệ thống';
      case 'admin':
        return 'Admin';
      default:
        return by;
    }
  }
}