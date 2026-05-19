// lib/features/social/models/post_model.dart

class Post {
  final String id;
  final String? userId;
  final String? nickname;
  final String? avatarUrl;
  final List<String> images;
  final String caption;
  final String? taggedStoreId;
  final String? taggedStoreName;
  final String? taggedItemId;
  final String? taggedItemName;
  final String visibility;
  final bool isHidden;
  final bool commentsDisabled;
  final int likesCount;
  final int commentsCount;
  final bool isLikedByMe;
  final bool isOwnPost;
  final DateTime createdAt;

  const Post({
    required this.id,
    this.userId,
    this.nickname,
    this.avatarUrl,
    required this.images,
    required this.caption,
    this.taggedStoreId,
    this.taggedStoreName,
    this.taggedItemId,
    this.taggedItemName,
    required this.visibility,
    required this.isHidden,
    required this.commentsDisabled,
    required this.likesCount,
    required this.commentsCount,
    required this.isLikedByMe,
    required this.isOwnPost,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        userId: json['userId'] as String?,
        nickname: json['nickname'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        images: List<String>.from(json['images'] ?? []),
        caption: json['caption'] as String? ?? '',
        taggedStoreId: json['taggedStoreId'] as String?,
        taggedStoreName: json['taggedStoreName'] as String?,
        taggedItemId: json['taggedItemId'] as String?,
        taggedItemName: json['taggedItemName'] as String?,
        visibility: json['visibility'] as String? ?? 'public',
        isHidden: json['isHidden'] as bool? ?? false,
        commentsDisabled: json['commentsDisabled'] as bool? ?? false,
        likesCount: json['likesCount'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        isLikedByMe: json['isLikedByMe'] as bool? ?? false,
        isOwnPost: json['isOwnPost'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Post copyWith({
    bool? isLikedByMe,
    int? likesCount,
    bool? isHidden,
    bool? commentsDisabled,
  }) =>
      Post(
        id: id,
        userId: userId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        images: images,
        caption: caption,
        taggedStoreId: taggedStoreId,
        taggedStoreName: taggedStoreName,
        taggedItemId: taggedItemId,
        taggedItemName: taggedItemName,
        visibility: visibility,
        isHidden: isHidden ?? this.isHidden,
        commentsDisabled: commentsDisabled ?? this.commentsDisabled,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isOwnPost: isOwnPost,
        createdAt: createdAt,
      );
}