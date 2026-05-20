// lib/features/notifications/models/notification_model.dart

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['_id'] as String? ?? json['id'] as String,
        type: json['type'] as String? ?? 'account',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        data: (json['data'] as Map<String, dynamic>?) ?? {},
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        data: data,
        createdAt: createdAt,
      );
}
