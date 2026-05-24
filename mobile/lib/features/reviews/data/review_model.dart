// lib/features/reviews/data/review_model.dart

class MyReviewReply {
  final String text;
  final DateTime at;
  final DateTime? editedAt;

  const MyReviewReply({required this.text, required this.at, this.editedAt});

  factory MyReviewReply.fromJson(Map<String, dynamic> json) => MyReviewReply(
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        editedAt: json['editedAt'] != null
            ? DateTime.parse(json['editedAt'] as String)
            : null,
      );
}

// Review tôi đã viết cho quán (toEntityType: 'store')
class MyReview {
  final String id;
  final String orderId;
  final String? orderCode;
  final String? storeName;
  final String? storeAvatarUrl;
  final String? storeId;
  final int stars;
  final String comment;
  final List<String> images;
  final bool isAnonymous;
  final MyReviewReply? reply;
  final DateTime createdAt;
  final DateTime? editedAt;

  const MyReview({
    required this.id,
    required this.orderId,
    this.orderCode,
    this.storeName,
    this.storeAvatarUrl,
    this.storeId,
    required this.stars,
    required this.comment,
    required this.images,
    required this.isAnonymous,
    this.reply,
    required this.createdAt,
    this.editedAt,
  });

  factory MyReview.fromJson(Map<String, dynamic> json) {
    final store = json['toEntityId'] as Map<String, dynamic>?;
    final rawOrder = json['orderId'];
    final orderMap = rawOrder is Map<String, dynamic> ? rawOrder : null;
    return MyReview(
      id: json['_id'] as String? ?? '',
      orderId: orderMap?['_id'] as String? ?? (rawOrder is String ? rawOrder : ''),
      orderCode: orderMap?['code'] as String?,
      storeName: store?['name'] as String?,
      storeAvatarUrl: store?['avatarImage'] as String?,
      storeId: store?['_id'] as String?,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      images: ((json['images'] as List?) ?? []).cast<String>(),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      reply: json['reply'] != null
          ? MyReviewReply.fromJson(json['reply'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'] as String)
          : null,
    );
  }

  // Rolling 24h: author có thể sửa/xóa nếu còn trong 24h kể từ lần reply cuối
  DateTime get _authorDeadline {
    final base = reply?.editedAt ?? reply?.at ?? createdAt;
    return base.add(const Duration(hours: 24));
  }

  bool get canEdit   => DateTime.now().isBefore(_authorDeadline);
  bool get canDelete => DateTime.now().isBefore(_authorDeadline);
}

// Review tôi nhận về từ chủ quán (toEntityType: 'customer')
class ReceivedReview {
  final String id;
  final String orderId;
  final String? orderCode;
  final String? fromNickname;
  final String? fromAvatar;
  final String? fromUserId;
  final bool isAnonymous;
  final int stars;
  final String comment;
  final List<String> images;
  final MyReviewReply? myReply;  // phản hồi của tôi (customer)
  final DateTime createdAt;
  final DateTime? editedAt;

  const ReceivedReview({
    required this.id,
    required this.orderId,
    this.orderCode,
    this.fromNickname,
    this.fromAvatar,
    this.fromUserId,
    required this.isAnonymous,
    required this.stars,
    required this.comment,
    required this.images,
    this.myReply,
    required this.createdAt,
    this.editedAt,
  });

  factory ReceivedReview.fromJson(Map<String, dynamic> json) {
    final rawOrder = json['orderId'];
    final orderMap = rawOrder is Map<String, dynamic> ? rawOrder : null;
    final rawFromUser = json['fromUserId'];
    final fromUserMap = rawFromUser is Map<String, dynamic> ? rawFromUser : null;
    return ReceivedReview(
      id: json['_id'] as String? ?? '',
      orderId: orderMap?['_id'] as String? ?? (rawOrder is String ? rawOrder : ''),
      orderCode: orderMap?['code'] as String? ?? json['orderCode'] as String?,
      fromNickname: json['isAnonymous'] == true ? null : (fromUserMap?['nickname'] as String? ?? json['nickname'] as String?),
      fromAvatar:   json['isAnonymous'] == true ? null : (fromUserMap?['avatar'] as String? ?? json['avatar'] as String?),
      fromUserId:   json['isAnonymous'] == true ? null : (fromUserMap?['_id'] as String? ?? (rawFromUser is String ? rawFromUser : null)),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      images: ((json['images'] as List?) ?? []).cast<String>(),
      myReply: json['reply'] != null
          ? MyReviewReply.fromJson(json['reply'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      editedAt: json['editedAt'] != null
          ? DateTime.tryParse(json['editedAt'] as String)
          : null,
    );
  }

  // Rolling 24h: tôi (customer) có thể reply nếu còn trong 24h kể từ lần quán sửa cuối
  DateTime get _replyDeadline {
    final base = editedAt ?? createdAt;
    return base.add(const Duration(hours: 24));
  }

  bool get canReply      => DateTime.now().isBefore(_replyDeadline);
  bool get canEditReply  => myReply != null && canReply;
}
