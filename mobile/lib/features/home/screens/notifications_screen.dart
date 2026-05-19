// lib/features/home/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';

final _dateFormat = DateFormat('dd/MM HH:mm');

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient().dio.get(ApiEndpoints.notifications);
  return List<Map<String, dynamic>>.from(res.data['notifications'] ?? res.data);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () {
              // Mark all read
              DioClient().dio.put('${ApiEndpoints.notifications}/read-all').catchError((_) {});
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: notifsAsync.when(
          data: (notifs) => notifs.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Chưa có thông báo', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _NotifTile(notif: notifs[i]),
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(notificationsProvider),
              child: const Text('Thử lại'),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final isRead = notif['isRead'] ?? false;
    final type = notif['type'] ?? '';
    final createdAt = notif['createdAt'] != null
        ? _dateFormat.format(DateTime.parse(notif['createdAt']).toLocal())
        : '';

    return InkWell(
      onTap: () => _navigate(context, notif),
      child: Container(
        color: isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor(type).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData(type), color: _iconColor(type), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'] ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif['body'] ?? '',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(createdAt, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Map<String, dynamic> notif) {
    final type = notif['type'] ?? '';
    final targetId = notif['targetId'] ?? '';
    if (type == 'order_status' || type == 'order_new' ||
        type == 'payment_action' || type == 'refund_action' ||
        type == 'review_reminder') {
      context.push('/order/$targetId');
    } else if (type == 'social') {
      context.push('/social/post/$targetId');
    } else if (type == 'account' || type == 'account_critical') {
      context.push('/profile/settings');
    }
  }

  IconData _iconData(String type) {
    if (type.startsWith('order')) return Icons.receipt_long_outlined;
    if (type == 'payment_action' || type == 'refund_action') return Icons.payments_outlined;
    if (type == 'social') return Icons.article_outlined;
    if (type == 'review_reminder') return Icons.star_outline;
    return Icons.notifications_outlined;
  }

  Color _iconColor(String type) {
    if (type.startsWith('order')) return Colors.blue;
    if (type == 'payment_action' || type == 'refund_action') return Colors.orange;
    if (type == 'social') return Colors.purple;
    if (type == 'review_reminder') return Colors.amber;
    return Colors.grey;
  }
}