// lib/core/widgets/user_avatar.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Avatar tròn dùng chung toàn app.
/// Không dùng ! operator — an toàn khi dispose giữa frame paint.
class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String? fallbackLabel;

  const UserAvatar({
    super.key,
    this.url,
    this.radius = 20,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasUrl = url != null && url!.isNotEmpty;

    if (!hasUrl) {
      return _Fallback(
        radius: radius,
        label: fallbackLabel,
        bg: cs.primaryContainer,
        fg: cs.onPrimaryContainer,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.surfaceContainerHighest,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url ?? '',          // không dùng url!
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Fallback(
            radius: radius,
            label: fallbackLabel,
            bg: cs.primaryContainer,
            fg: cs.onPrimaryContainer,
          ),
          errorWidget: (_, __, ___) => _Fallback(
            radius: radius,
            label: fallbackLabel,
            bg: cs.primaryContainer,
            fg: cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final double radius;
  final String? label;
  final Color bg;
  final Color fg;

  const _Fallback({
    required this.radius,
    required this.bg,
    required this.fg,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        (label != null && label!.isNotEmpty) ? label![0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// lib/core/widgets/user_avatar.dart