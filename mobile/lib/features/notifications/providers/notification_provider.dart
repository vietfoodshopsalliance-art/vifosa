// lib/features/notifications/providers/notification_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationState {
  final List<AppNotification> items;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final bool hasMore;

  const NotificationState({
    this.items = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page = 1,
    this.hasMore = false,
  });

  NotificationState copyWith({
    List<AppNotification>? items,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    int? page,
    bool? hasMore,
  }) =>
      NotificationState(
        items: items ?? this.items,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, page: 1, items: []);
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': 1, 'limit': 20},
      );
      final raw = res.data is Map ? (res.data['notifications'] ?? res.data['data'] ?? []) : res.data;
      final items = (raw as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      final unread = items.where((n) => !n.isRead).length;
      state = state.copyWith(
        items: items,
        unreadCount: unread,
        isLoading: false,
        page: 2,
        hasMore: items.length >= 20,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await DioClient.instance.get(
        ApiEndpoints.notifications,
        queryParameters: {'page': state.page, 'limit': 20},
      );
      final raw = res.data is Map ? (res.data['notifications'] ?? res.data['data'] ?? []) : res.data;
      final more = (raw as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(
        items: [...state.items, ...more],
        isLoadingMore: false,
        page: state.page + 1,
        hasMore: more.length >= 20,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await DioClient.instance.patch(ApiEndpoints.notifRead(id));
      state = state.copyWith(
        items: state.items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 9999),
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await DioClient.instance.patch(ApiEndpoints.notifications);
      state = state.copyWith(
        items: state.items.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (_) => NotificationNotifier(),
);
