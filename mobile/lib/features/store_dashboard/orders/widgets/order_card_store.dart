// lib/features/store_dashboard/orders/widgets/order_card_store.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/store_order.dart';
import '../../../../core/widgets/order_code_text.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

// ─── Card modes ───────────────────────────────────────────────────────────────

enum OrderCardMode { pending, active, history }

class OrderCardStore extends StatefulWidget {
  final StoreOrder order;
  final OrderCardMode mode;

  // Countdown settings
  final int autoCancelMinutes;    // for pending countdown
  final int autoConfirmMinutes;   // for auto-accept info
  final int deliveryTimeoutMinutes; // for active countdown

  // Rejection countdown (managed by parent)
  final int? rejectCountdown; // null = not rejecting; 0-10 = countdown active

  // Tap handlers
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onRejectStart;   // start rejection countdown
  final VoidCallback? onRejectCancel;  // cancel rejection
  final VoidCallback? onDeliver;       // Tab 2: deliver/complete
  final VoidCallback? onReturnToPending;
  final void Function(double amount)? onRecordPayment;

  const OrderCardStore({
    super.key,
    required this.order,
    this.mode = OrderCardMode.pending,
    this.autoCancelMinutes = 15,
    this.autoConfirmMinutes = 0,
    this.deliveryTimeoutMinutes = 180,
    this.rejectCountdown,
    this.onTap,
    this.onAccept,
    this.onRejectStart,
    this.onRejectCancel,
    this.onDeliver,
    this.onReturnToPending,
    this.onRecordPayment,
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
    _startTimer();
  }

  @override
  void didUpdateWidget(OrderCardStore old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode ||
        old.order.id != widget.order.id ||
        old.autoCancelMinutes != widget.autoCancelMinutes ||
        old.deliveryTimeoutMinutes != widget.deliveryTimeoutMinutes) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    final deadline = _deadline;
    if (deadline == null) return;
    _calcRemaining(deadline);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _calcRemaining(deadline);
    });
  }

  DateTime? get _deadline {
    if (widget.mode == OrderCardMode.pending) {
      final base = widget.order.pendingAt ?? widget.order.createdAt;
      return base.add(Duration(minutes: widget.autoCancelMinutes));
    }
    if (widget.mode == OrderCardMode.active) {
      final base = widget.order.acceptedAt ?? widget.order.createdAt;
      return base.add(Duration(minutes: widget.deliveryTimeoutMinutes));
    }
    return null;
  }

  void _calcRemaining(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── Timer display ─────────────────────────────────────────────────────────

  String get _timerText {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    if (h > 0) return 'còn ${h}g ${m.toString().padLeft(2, '0')}\'';
    if (m > 0) return 'còn ${m}\'';
    return 'còn ${s}s';
  }

  bool get _isUrgent {
    if (widget.mode == OrderCardMode.pending) return _remaining.inSeconds < 180;
    if (widget.mode == OrderCardMode.active) return _remaining.inMinutes < 30;
    return false;
  }

  // ─── Payment badge ─────────────────────────────────────────────────────────

  Widget _paymentBadge(BuildContext context) {
    final o = widget.order;
    if (o.paymentMethod == 'cod') {
      return _chip('COD', const Color(0xFFFFA000), const Color(0xFFFFF3CD));
    }
    switch (o.paymentStatus) {
      case 'paid_full':
        return _chip('Đã thanh toán', Colors.green.shade700, Colors.green.shade50);
      case 'reported_paid':
        return _chip('Đã báo CK', Colors.green.shade600, Colors.green.shade50);
      case 'partial':
        return _chip('Trả 1 phần', Colors.orange.shade700, Colors.orange.shade50);
      default:
        return _chip('Chưa CK', Colors.red.shade600, Colors.red.shade50);
    }
  }

  Widget _chip(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─── Delivery label ────────────────────────────────────────────────────────

  String get _deliveryLabel {
    switch (widget.order.deliveryMethod) {
      case 'store_delivery':
        return '🛵 Quán giao';
      case 'self_pickup':
        return '🚶 Tự đến';
      case 'customer_shipper':
        return '🚚 Shipper riêng';
      // legacy
      case 'A': return '🛵 Quán giao';
      case 'B': return '🚶 Tự đến';
      case 'C': return '🚚 Shipper riêng';
      default:
        return widget.order.deliveryMethod;
    }
  }

  // ─── Action button text ────────────────────────────────────────────────────

  String get _acceptBtnLabel {
    if (widget.order.paymentMethod == 'cod') {
      return 'Bàn giao cho shipper và thu tiền';
    }
    return 'Nhận đơn';
  }

  String get _deliverBtnLabel {
    if (widget.order.mainStatus == 'delivering') return 'Đã giao';
    return 'Bắt đầu giao';
  }

  // ─── Auto-action hint ─────────────────────────────────────────────────────

  Widget? _autoHint() {
    if (widget.mode != OrderCardMode.pending) return null;
    if (widget.autoConfirmMinutes > 0) {
      final mins = widget.autoConfirmMinutes;
      return _hintRow('Tự động nhận đơn sau $mins phút');
    }
    if (widget.autoCancelMinutes > 0) {
      return _hintRow(
          'Tự động hủy đơn sau ${widget.autoCancelMinutes} phút');
    }
    return null;
  }

  Widget _hintRow(String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(text,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      );

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final isRejecting = widget.rejectCountdown != null;
    final rc = widget.rejectCountdown ?? 0;

    Color? cardColor;
    if (isRejecting) cardColor = Colors.grey.shade100;
    if (widget.mode == OrderCardMode.history && o.mainStatus == 'cancelled') {
      cardColor = Colors.grey.shade50;
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: code + timer/status ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: OrderCodeText(
                        code: o.code, suffixFontSize: 16),
                  ),
                  if (isRejecting) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '00:${rc.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ] else if (o.isPreOrder) ...[
                    _chip('Đặt trước', Colors.purple.shade600,
                        Colors.purple.shade50),
                  ] else if (_deadline != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isUrgent
                            ? Colors.red.withOpacity(0.12)
                            : Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _timerText,
                        style: TextStyle(
                          color: _isUrgent
                              ? Colors.red
                              : Colors.blue.shade700,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ] else if (widget.mode == OrderCardMode.history) ...[
                    _historyStatusBadge(o),
                  ],
                ],
              ),
              const SizedBox(height: 5),

              // ── Row 2: delivery method + payment badge ─────────────────
              Row(
                children: [
                  Text(_deliveryLabel,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  _paymentBadge(context),
                ],
              ),

              // ── Divider ────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),

              // ── Items ──────────────────────────────────────────────────
              ...o.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${item.name}  ×${item.quantity}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        Text(
                          '${_currency.format(item.price * item.quantity)} đ',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 4),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // ── Phí ship + Tổng ────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Phí ship:',
                      style: TextStyle(fontSize: 12, color: Colors.black54)),
                  Text('${_currency.format(o.shipFee)} đ',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng:',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    '${_currency.format(o.total)} đ',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),

              // ── Còn phải thu (non-COD only) ─────────────────────────────
              if (o.paymentMethod != 'cod') ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: widget.onRecordPayment != null
                      ? () => _showPaymentSheet(context)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: o.remainingAmount <= 0
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: o.remainingAmount <= 0
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Còn phải thu:',
                          style: TextStyle(
                            fontSize: 12,
                            color: o.remainingAmount <= 0
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_currency.format(o.remainingAmount)} đ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: o.remainingAmount <= 0
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // ── Address ────────────────────────────────────────────────
              if (o.deliveryAddressText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(o.deliveryAddressText,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54)),
                    ),
                  ],
                ),
              ],

              // ── Note ───────────────────────────────────────────────────
              if (o.note != null && o.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ghi chú khách: ${o.note}',
                    style: const TextStyle(
                        fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],

              // ── Pre-order scheduled time ───────────────────────────────
              if (o.isPreOrder) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 13, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'Vào hàng đợi lúc 8:00am sáng mai',
                      style: TextStyle(
                          fontSize: 11, color: Colors.purple.shade600),
                    ),
                  ],
                ),
              ],

              // ── Reject countdown message ────────────────────────────────
              if (isRejecting) ...[
                const SizedBox(height: 8),
                Text(
                  'Đơn này sẽ bị xóa sau $rc giây',
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],

              // ── History: cancel reason ─────────────────────────────────
              if (widget.mode == OrderCardMode.history &&
                  o.cancelInfo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'x ${_cancelByLabel(o.cancelInfo!.cancelledBy)}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],

              // ── History: completed time ────────────────────────────────
              if (widget.mode == OrderCardMode.history) ...[
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm dd/MM').format(o.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey),
                ),
              ],

              // ── Action buttons ─────────────────────────────────────────
              if (_showActions) ...[
                const SizedBox(height: 10),
                _buildActionRow(),
              ],

              // ── Auto-action hint ───────────────────────────────────────
              if (_autoHint() != null) _autoHint()!,

              // ── Active tab timer hint ──────────────────────────────────
              if (widget.mode == OrderCardMode.active && _deadline != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Tự động hoàn thành giao hàng sau '
                        '${widget.deliveryTimeoutMinutes} phút',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _showActions =>
      widget.mode == OrderCardMode.pending ||
      widget.mode == OrderCardMode.active;

  Widget _buildActionRow() {
    final isRejecting = widget.rejectCountdown != null;

    if (widget.mode == OrderCardMode.pending) {
      if (isRejecting) {
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade800,
              side: BorderSide(color: Colors.orange.shade300)),
          onPressed: widget.onRejectCancel,
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Nhận lại'),
        );
      }
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade300)),
              onPressed: widget.onRejectStart,
              child: const Text('X Từ chối'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: widget.onAccept,
              child: Text(_acceptBtnLabel),
            ),
          ),
        ],
      );
    }

    // Active tab — delivered: chờ khách xác nhận, không có nút action
    if (widget.order.mainStatus == 'delivered') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded,
                size: 16, color: Colors.green.shade700),
            const SizedBox(width: 6),
            Text(
              'Chờ khách xác nhận nhận hàng',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade400)),
          onPressed: widget.onReturnToPending,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Trả lại'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: widget.onDeliver,
            child: Text(_deliverBtnLabel),
          ),
        ),
      ],
    );
  }

  Widget _historyStatusBadge(StoreOrder o) {
    if (o.mainStatus == 'completed') {
      return _chip('Hoàn thành', Colors.green.shade700, Colors.green.shade50);
    }
    if (o.mainStatus == 'cancelled') {
      return _chip('Đã hủy', Colors.grey.shade600, Colors.grey.shade100);
    }
    return _chip(o.mainStatus, Colors.blueGrey, Colors.blueGrey.shade50);
  }

  String _cancelByLabel(String by) {
    switch (by) {
      case 'store': return 'Quán hủy';
      case 'customer': return 'Khách hủy';
      case 'system': return 'Hệ thống hủy';
      case 'admin': return 'Admin hủy';
      default: return 'Đã hủy';
    }
  }

  void _showPaymentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentSheet(
        order: widget.order,
        onConfirm: widget.onRecordPayment!,
      ),
    );
  }
}

// ─── Payment bottom sheet ──────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final StoreOrder order;
  final void Function(double) onConfirm;
  const _PaymentSheet({required this.order, required this.onConfirm});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.order.remainingAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Ghi nhận thu tiền',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Còn lại: ${_currency.format(widget.order.remainingAmount)} đ',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Số tiền nhận được (đ)',
              border: OutlineInputBorder(),
              suffixText: 'đ',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final amount =
                  double.tryParse(_ctrl.text.replaceAll(',', '')) ??
                      widget.order.remainingAmount;
              Navigator.pop(context);
              widget.onConfirm(amount);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
