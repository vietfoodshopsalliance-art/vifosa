// lib/core/widgets/status_badge.dart

import 'package:flutter/material.dart';
import '../models/store.dart';

// OrderStatus — sẽ mở rộng ở module 05
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  delivering,
  delivered,
  completed,
  cancelled,
  refunded,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? dotColor;
  final bool showDot;
  final bool pulseDot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.dotColor,
    this.showDot = true,
    this.pulseDot = false,
  });

  // ── Factory: StoreStatus ────────────────────────────────────────────────

  factory StatusBadge.store(StoreStatus status) {
    switch (status) {
      case StoreStatus.open:
        return const StatusBadge(
          label: 'Đang mở',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
          dotColor: Color(0xFF22C55E),
          pulseDot: true,
        );
      case StoreStatus.preOrder:                        // khớp enum store.dart
        return const StatusBadge(
          label: 'Đặt trước',
          backgroundColor: Color(0xFFEFF6FF),
          textColor: Color(0xFF1D4ED8),
          dotColor: Color(0xFF3B82F6),
        );
      case StoreStatus.emergencyClosed:
        return const StatusBadge(
          label: 'Đang đóng',
          backgroundColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF6B7280),
          dotColor: Color(0xFF9CA3AF),
        );
      case StoreStatus.suspended:
        return const StatusBadge(
          label: 'Bị khoá',
          backgroundColor: Color(0xFFFEF2F2),
          textColor: Color(0xFFB91C1C),
          dotColor: Color(0xFFEF4444),
        );
    }
  }

  // ── Factory: OrderStatus ────────────────────────────────────────────────

  factory StatusBadge.order(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const StatusBadge(
          label: 'Chờ xác nhận',
          backgroundColor: Color(0xFFFEF9EC),
          textColor: Color(0xFF92400E),
          dotColor: Color(0xFFF59E0B),
          pulseDot: true,
        );
      case OrderStatus.confirmed:
        return const StatusBadge(
          label: 'Đã xác nhận',
          backgroundColor: Color(0xFFEFF6FF),
          textColor: Color(0xFF1D4ED8),
          dotColor: Color(0xFF3B82F6),
        );
      case OrderStatus.preparing:
        return const StatusBadge(
          label: 'Đang chuẩn bị',
          backgroundColor: Color(0xFFF5F3FF),
          textColor: Color(0xFF5B21B6),
          dotColor: Color(0xFF8B5CF6),
          pulseDot: true,
        );
      case OrderStatus.delivering:
        return const StatusBadge(
          label: 'Đang giao',
          backgroundColor: Color(0xFFECFEFF),
          textColor: Color(0xFF0E7490),
          dotColor: Color(0xFF06B6D4),
          pulseDot: true,
        );
      case OrderStatus.delivered:
        return const StatusBadge(
          label: 'Đã giao',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
          dotColor: Color(0xFF22C55E),
        );
      case OrderStatus.completed:
        return const StatusBadge(
          label: 'Hoàn thành',
          backgroundColor: Color(0xFFDCFCE7),
          textColor: Color(0xFF166534),
          dotColor: Color(0xFF16A34A),
        );
      case OrderStatus.cancelled:
        return const StatusBadge(
          label: 'Đã huỷ',
          backgroundColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF6B7280),
          dotColor: Color(0xFF9CA3AF),
        );
      case OrderStatus.refunded:
        return const StatusBadge(
          label: 'Đã hoàn tiền',
          backgroundColor: Color(0xFFFDF4FF),
          textColor: Color(0xFF6B21A8),
          dotColor: Color(0xFFA855F7),
        );
    }
  }

  // ── Factory: từ string API ──────────────────────────────────────────────

  factory StatusBadge.fromStoreString(String status) {
    switch (status) {
      case 'open':             return StatusBadge.store(StoreStatus.open);
      case 'preorder':         return StatusBadge.store(StoreStatus.preOrder);
      case 'emergency_closed': return StatusBadge.store(StoreStatus.emergencyClosed);
      case 'suspended':        return StatusBadge.store(StoreStatus.suspended);
      default:
        return StatusBadge(
          label: status,
          backgroundColor: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
        );
    }
  }

  factory StatusBadge.fromOrderString(String status) {
    const map = {
      'pending':    OrderStatus.pending,
      'confirmed':  OrderStatus.confirmed,
      'preparing':  OrderStatus.preparing,
      'delivering': OrderStatus.delivering,
      'delivered':  OrderStatus.delivered,
      'completed':  OrderStatus.completed,
      'cancelled':  OrderStatus.cancelled,
      'refunded':   OrderStatus.refunded,
    };
    final parsed = map[status];
    if (parsed != null) return StatusBadge.order(parsed);
    return StatusBadge(
      label: status,
      backgroundColor: const Color(0xFFF3F4F6),
      textColor: const Color(0xFF6B7280),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _Dot(color: dotColor ?? textColor, pulse: pulseDot),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot ────────────────────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  const _Dot({required this.color, required this.pulse});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _opacity = Tween<double>(begin: 1.0, end: 0.25).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (!widget.pulse) return dot;
    return FadeTransition(opacity: _opacity, child: dot);
  }
}

// lib/core/widgets/status_badge.dart