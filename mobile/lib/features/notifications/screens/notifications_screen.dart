// lib/features/notifications/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTapNotification(BuildContext context, AppNotification notification) {
    ref.read(notificationProvider.notifier).markAsRead(notification.id);
    _navigateByType(context, notification);
  }

  void _navigateByType(BuildContext context, AppNotification notification) {
    switch (notification.type) {
      case 'order_new':
      case 'order_status':
      case 'order_deadline':
      case 'payment_action':
      case 'refund_action':
      case 'refund_status':
      case 'review_reminder':
        final orderId = notification.data['orderId'] as String?;
        if (orderId != null) Navigator.pushNamed(context, '/order/$orderId');
        break;
      case 'social':
        final postId = notification.data['postId'] as String?;
        if (postId != null) Navigator.pushNamed(context, '/social/post/$postId');
        break;
      case 'account':
      case 'account_critical':
        Navigator.pushNamed(context, '/profile/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: state.unreadCount > 0
                ? () => ref.read(notificationProvider.notifier).markAllAsRead()
                : null,
            child: const Text('Đọc tất cả', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
              ? const _EmptyView()
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationProvider.notifier).fetchNotifications(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final n = state.items[index];
                      return _NotificationTile(
                        notification: n,
                        onTap: () => _onTapNotification(context, n),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Tile ─────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  static const _typeConfig = <String, _TypeConfig>{
    'order_new':      _TypeConfig(Icons.inventory_2_outlined,      Color(0xFFFF7043)),
    'order_status':   _TypeConfig(Icons.inventory_2_outlined,      Color(0xFFFF7043)),
    'order_deadline': _TypeConfig(Icons.alarm,                     Color(0xFFE53935)),
    'payment_action': _TypeConfig(Icons.credit_card_outlined,      Color(0xFFFFC107)),
    'refund_action':  _TypeConfig(Icons.monetization_on_outlined,  Color(0xFF43A047)),
    'refund_status':  _TypeConfig(Icons.monetization_on_outlined,  Color(0xFF43A047)),
    'review_reminder':_TypeConfig(Icons.star_outline_rounded,      Color(0xFFFFC107)),
    'social':         _TypeConfig(Icons.chat_bubble_outline,       Color(0xFF7E57C2)),
    'account':        _TypeConfig(Icons.person_outline,            Color(0xFFE53935)),
    'account_critical':_TypeConfig(Icons.person_outline,           Color(0xFFE53935)),
  };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1)   return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1)    return '${diff.inHours} giờ trước';
    if (diff.inDays < 30)   return '${diff.inDays} ngày trước';
    return '${(diff.inDays / 30).floor()} tháng trước';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[notification.type] ??
        const _TypeConfig(Icons.notifications_outlined, Colors.grey);
    final unread = !notification.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeConfig {
  final IconData icon;
  final Color color;
  const _TypeConfig(this.icon, this.color);
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Chưa có thông báo',
              style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        ],
      ),
    );
  }
}