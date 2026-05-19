// lib/features/notifications/providers/notification_provider.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationState {
  final List<RemoteMessage> messages;
  final RemoteMessage? latest;

  const NotificationState({
    this.messages = const [],
    this.latest,
  });
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  void handleIncomingMessage(RemoteMessage message) {
    state = NotificationState(
      messages: [message, ...state.messages],
      latest: message,
    );
  }

  void clearLatest() {
    state = NotificationState(messages: state.messages, latest: null);
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
  (_) => NotificationNotifier(),
);
