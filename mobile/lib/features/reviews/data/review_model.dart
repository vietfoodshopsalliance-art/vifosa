// mobile/lib/features/reviews/data/review_model.dart

class ReviewReply {
  final String text;
  final DateTime at;
  final DateTime? editedAt;

  ReviewReply({required this.text, required this.at, this.editedAt});

  factory ReviewReply.fromJson(Map<String, dynamic> json) => ReviewReply(
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
        editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
      );
}

class ReviewAuthor {
  final String nickname;
  final String? avatar;

  ReviewAuthor({required this.nickname, this.avatar});

  factory ReviewAuthor.fromJson(Map<String, dynamic> json) => ReviewAuthor(
        nickname: json['nickname'] as String,
        avatar: json['avatar'] as String?,
      );
}

class Review {
  final String id;
  final String orderId;
  final int stars;
  final String comment;
  final List<String> images;
  final bool isAnonymous;
  final ReviewAuthor? author;
  final ReviewReply? reply;
  final DateTime createdAt;
  final DateTime? editedAt;
  final Map<String, dynamic>? orderInfo;

  Review({
    required this.id,
    required this.orderId,
    required this.stars,
    required this.comment,
    required this.images,
    required this.isAnonymous,
    this.author,
    this.reply,
    required this.createdAt,
    this.editedAt,
    this.orderInfo,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['_id'] as String,
        orderId: json['orderId'] as String,
        stars: json['stars'] as int,
        comment: json['comment'] as String? ?? '',
        images: List<String>.from(json['images'] ?? []),
        isAnonymous: json['isAnonymous'] as bool? ?? false,
        author: json['author'] != null ? ReviewAuthor.fromJson(json['author']) : null,
        reply: json['reply'] != null ? ReviewReply.fromJson(json['reply']) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
        orderInfo: json['orderInfo'] as Map<String, dynamic>?,
      );

  bool get canEdit => DateTime.now().difference(createdAt).inHours < 24;
  bool get canDelete => DateTime.now().difference(createdAt).inHours < 24;
}

class StoreReviewsResult {
  final List<Review> data;
  final double avgRating;
  final int totalReviews;
  final Map<String, int> distribution;
  final int page;
  final bool hasMore;

  StoreReviewsResult({
    required this.data,
    required this.avgRating,
    required this.totalReviews,
    required this.distribution,
    required this.page,
    required this.hasMore,
  });

  factory StoreReviewsResult.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    final dist = (stats['distribution'] as Map<String, dynamic>?) ?? {};
    return StoreReviewsResult(
      data: (json['data'] as List).map((e) => Review.fromJson(e)).toList(),
      avgRating: (stats['avgRating'] as num).toDouble(),
      totalReviews: stats['totalReviews'] as int,
      distribution: dist.map((k, v) => MapEntry(k, v as int)),
      page: json['page'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }
}