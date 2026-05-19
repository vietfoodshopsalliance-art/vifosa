// lib/core/utils/app_snackbar.dart

import 'package:flutter/material.dart';

enum _SnackType { success, error, info, warning }

/// Tiện ích hiển thị SnackBar nhất quán trong toàn app.
///
/// Sử dụng:
/// ```dart
/// AppSnackbar.success(context, 'Đặt hàng thành công!');
/// AppSnackbar.error(context, 'Không thể kết nối máy chủ.');
/// ```
abstract final class AppSnackbar {
  // ── Public API ─────────────────────────────────────────────────────────────

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      _show(context, message, _SnackType.success, duration: duration, action: action);

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) =>
      _show(context, message, _SnackType.error, duration: duration, action: action);

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      _show(context, message, _SnackType.info, duration: duration, action: action);

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) =>
      _show(context, message, _SnackType.warning, duration: duration, action: action);

  // ── Internal ───────────────────────────────────────────────────────────────

  static void _show(
    BuildContext context,
    String message,
    _SnackType type, {
    required Duration duration,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(_icon(type), color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: _color(type),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          action: action,
        ),
      );
  }

  static IconData _icon(_SnackType type) => switch (type) {
        _SnackType.success => Icons.check_circle_outline,
        _SnackType.error => Icons.error_outline,
        _SnackType.warning => Icons.warning_amber_outlined,
        _SnackType.info => Icons.info_outline,
      };

  static Color _color(_SnackType type) => switch (type) {
        _SnackType.success => const Color(0xFF2E7D32), // green-800
        _SnackType.error => const Color(0xFFC62828),   // red-800
        _SnackType.warning => const Color(0xFFE65100), // orange-900
        _SnackType.info => const Color(0xFF1565C0),    // blue-800
      };
}

// lib/core/utils/app_snackbar.dart