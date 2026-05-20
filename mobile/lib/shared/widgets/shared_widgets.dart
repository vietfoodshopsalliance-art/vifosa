// lib/shared/widgets/shared_widgets.dart
// Design-system primitives used across the app.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

export 'status_badge.dart';
export 'app_avatar.dart';
export 'section_header.dart';
export 'role_switcher_dropdown.dart';

// ─── Spacing constants ────────────────────────────────────────────────────────

class VS {
  VS._();
  static const double xs      = 4;
  static const double sm      = 8;
  static const double md      = 12;
  static const double base    = 16;
  static const double lg      = 20;
  static const double xl      = 24;
  static const double xxl     = 32;

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
}

// ─── Color palette ────────────────────────────────────────────────────────────

class VColors {
  VColors._();

  static const Color primary = AppTheme.primary;
  static const Color success = AppTheme.success;
  static const Color warning = AppTheme.warning;
  static const Color error   = AppTheme.danger;
  static const Color info    = Color(0xFF0288D1);

  static const Color bg      = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;

  static const Color n50  = Color(0xFFFAFAFA);
  static const Color n100 = Color(0xFFF5F5F5);
  static const Color n200 = Color(0xFFEEEEEE);
  static const Color n300 = Color(0xFFE0E0E0);
  static const Color n400 = Color(0xFFBDBDBD);
  static const Color n500 = Color(0xFF9E9E9E);
  static const Color n600 = Color(0xFF757575);
  static const Color n700 = Color(0xFF616161);
  static const Color n800 = Color(0xFF424242);
  static const Color n900 = Color(0xFF212121);
}

// ─── Text styles ─────────────────────────────────────────────────────────────

class VTextStyles {
  VTextStyles._();

  static const TextStyle h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: VColors.n800);
  static const TextStyle h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: VColors.n800);
  static const TextStyle h3 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: VColors.n800);

  static const TextStyle body1 = TextStyle(fontSize: 14, color: VColors.n700);
  static const TextStyle body2 = TextStyle(fontSize: 12, color: VColors.n500);

  static const TextStyle label1 = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: VColors.n800);
  static const TextStyle label2 = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: VColors.n700);
}

// ─── Shadow presets ───────────────────────────────────────────────────────────

class VShadows {
  VShadows._();

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

// ─── Section divider ─────────────────────────────────────────────────────────

class VSectionDivider extends StatelessWidget {
  const VSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: VS.sm);
  }
}

// ─── VCard ────────────────────────────────────────────────────────────────────

class VCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double radius;

  const VCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.radius = VS.radiusMd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VColors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: VColors.n200),
            boxShadow: VShadows.sm,
          ),
          padding: padding ?? const EdgeInsets.all(VS.base),
          child: child,
        ),
      ),
    );
  }
}

// ─── VEmptyState ─────────────────────────────────────────────────────────────

class VEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const VEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VS.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: VColors.n400),
            const SizedBox(height: VS.md),
            Text(title, style: VTextStyles.h3.copyWith(color: VColors.n600)),
            if (subtitle != null) ...[
              const SizedBox(height: VS.sm),
              Text(
                subtitle!,
                style: VTextStyles.body2,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── VCountdown ───────────────────────────────────────────────────────────────

class VCountdown extends StatelessWidget {
  final Duration remaining;
  final bool urgent;

  const VCountdown({super.key, required this.remaining, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final label = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgent ? VColors.error.withOpacity(0.1) : VColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(VS.radiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: urgent ? VColors.error : VColors.warning,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ─── VPrice ───────────────────────────────────────────────────────────────────

class VPrice extends StatelessWidget {
  final int amount;
  final TextStyle? style;

  const VPrice({super.key, required this.amount, this.style});

  @override
  Widget build(BuildContext context) {
    final formatted = _formatVnd(amount);
    return Text(
      formatted,
      style: style ?? const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: VColors.n800,
      ),
    );
  }

  static String _formatVnd(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf}đ';
  }
}

// ─── VButton ─────────────────────────────────────────────────────────────────

class VButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;

  const VButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? VColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VS.radiusMd),
          ),
        ),
        child: loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── VSheetHandle ─────────────────────────────────────────────────────────────

class VSheetHandle extends StatelessWidget {
  const VSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: VColors.n300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
