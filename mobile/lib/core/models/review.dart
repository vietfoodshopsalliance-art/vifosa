// lib/core/models/review.dart

class ReviewReply {
  final String text;
  final DateTime at;
  final DateTime? editedAt;

  const ReviewReply({
    required this.text,
    required this.at,
    this.editedAt,
  });

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'at': at.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };
}

enum ReviewTargetType { store, customer }

class Review {
  final String id;
  final String orderId;

  /// null khi isAnonymous == true và caller là customer/store
  /// (backend che danh tính; admin/mod nhận đầy đủ)
  final String? fromUserId;
  final String? nickname;
  final String? avatar;

  final ReviewTargetType toEntityType;
  final String toEntityId;

  final int stars; // 1–5
  final String comment;
  final List<String> images;

  final bool isAnonymous;
  final bool isHiddenByAdmin;

  final ReviewReply? reply;

  final DateTime createdAt;
  final DateTime? editedAt;

  const Review({
    required this.id,
    required this.orderId,
    this.fromUserId,
    this.nickname,
    this.avatar,
    required this.toEntityType,
    required this.toEntityId,
    required this.stars,
    required this.comment,
    required this.images,
    required this.isAnonymous,
    required this.isHiddenByAdmin,
    this.reply,
    required this.createdAt,
    this.editedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['_id'] as String,
        orderId: json['orderId'] as String,
        fromUserId: json['fromUserId'] as String?,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        toEntityType: (json['toEntityType'] as String) == 'store'
            ? ReviewTargetType.store
            : ReviewTargetType.customer,
        toEntityId: json['toEntityId'] as String,
        stars: json['stars'] as int,
        comment: json['comment'] as String,
        images: (json['images'] as List<dynamic>).cast<String>(),
        isAnonymous: json['isAnonymous'] as bool,
        isHiddenByAdmin: json['isHiddenByAdmin'] as bool,
        reply: json['reply'] != null
            ? ReviewReply.fromJson(json['reply'] as Map<String, dynamic>)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'orderId': orderId,
        if (fromUserId != null) 'fromUserId': fromUserId,
        if (nickname != null) 'nickname': nickname,
        if (avatar != null) 'avatar': avatar,
        'toEntityType': toEntityType.name,
        'toEntityId': toEntityId,
        'stars': stars,
        'comment': comment,
        'images': images,
        'isAnonymous': isAnonymous,
        'isHiddenByAdmin': isHiddenByAdmin,
        if (reply != null) 'reply': reply!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };
}

// lib/core/models/review.dart