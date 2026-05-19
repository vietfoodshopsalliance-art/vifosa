// lib/features/notifications/widgets/in_app_banner.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_provider.dart';

class InAppNotificationOverlay extends ConsumerWidget {
  final Widget child;

  const InAppNotificationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(notificationProvider).latest;
    return Stack(
      children: [
        child,
        if (latest != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _NotificationBanner(
              message: latest,
              onDismiss: () =>
                  ref.read(notificationProvider.notifier).clearLatest(),
            ),
          ),
      ],
    );
  }
}

class _NotificationBanner extends StatefulWidget {
  final RemoteMessage message;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.message.notification;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (notif?.title != null)
                    Text(
                      notif!.title!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  if (notif?.body != null)
                    Text(
                      notif!.body!,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
