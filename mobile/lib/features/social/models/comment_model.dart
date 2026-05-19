// lib/features/social/models/comment_model.dart

class Comment {
  final String id;
  final String postId;
  final String? parentId;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String content;
  final int likesCount;
  final bool isLikedByMe;
  final bool isOwnComment;
  final List<Comment> replies;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.content,
    required this.likesCount,
    required this.isLikedByMe,
    required this.isOwnComment,
    required this.replies,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        postId: json['postId'] as String,
        parentId: json['parentId'] as String?,
        userId: json['userId'] as String,
        nickname: json['nickname'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        content: json['content'] as String,
        likesCount: json['likesCount'] as int? ?? 0,
        isLikedByMe: json['isLikedByMe'] as bool? ?? false,
        isOwnComment: json['isOwnComment'] as bool? ?? false,
        replies: (json['replies'] as List<dynamic>?)
                ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Comment copyWith({bool? isLikedByMe, int? likesCount}) => Comment(
        id: id,
        postId: postId,
        parentId: parentId,
        userId: userId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        content: content,
        likesCount: likesCount ?? this.likesCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isOwnComment: isOwnComment,
        replies: replies,
        createdAt: createdAt,
      );
}