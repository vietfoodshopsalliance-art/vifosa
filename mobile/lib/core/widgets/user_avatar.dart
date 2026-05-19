// lib/core/widgets/user_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget avatar tròn dùng chung toàn app.
/// [url] — Cloudinary URL (nullable → hiện placeholder chữ cái đầu).
/// [radius] — bán kính, default 20.
class UserAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String? fallbackLabel; // chữ cái đầu nếu không có ảnh

  const UserAvatar({
    super.key,
    this.url,
    this.radius = 20,
    this.fallbackLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            placeholder: (_, __) => _Fallback(
              radius: radius,
              label: fallbackLabel,
              color: colorScheme.primaryContainer,
              textColor: colorScheme.onPrimaryContainer,
            ),
            errorWidget: (_, __, ___) => _Fallback(
              radius: radius,
              label: fallbackLabel,
              color: colorScheme.primaryContainer,
              textColor: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      );
    }

    return _Fallback(
      radius: radius,
      label: fallbackLabel,
      color: colorScheme.primaryContainer,
      textColor: colorScheme.onPrimaryContainer,
    );
  }
}

class _Fallback extends StatelessWidget {
  final double radius;
  final String? label;
  final Color color;
  final Color textColor;

  const _Fallback({
    required this.radius,
    required this.color,
    required this.textColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (label?.isNotEmpty == true) ? label![0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}