// lib/features/social/widgets/post_card.dart

import 'package:flutter/material.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/post_model.dart';
import 'like_button.dart';
import '../../../core/widgets/report_dialog.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final void Function(String postId) onToggleLike;
  final void Function(Post) onTapPost;
  final void Function(Post, Map<String, dynamic>) onUpdatePost;
  final void Function(String postId) onDeletePost;

  const PostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onTapPost,
    required this.onUpdatePost,
    required this.onDeletePost,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _currentImage = 0;
  bool _expanded = false;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _showMenu(BuildContext context) {
    final post = widget.post;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: post.isOwnPost
              ? [
                  ListTile(
                    leading: Icon(
                      post.isHidden ? Icons.visibility : Icons.visibility_off,
                    ),
                    title: Text(post.isHidden ? 'Hiện post' : 'Ẩn post'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onUpdatePost(
                          post, {'isHidden': !post.isHidden});
                    },
                  ),
                  ListTile(
                    leading: Icon(post.commentsDisabled
                        ? Icons.comment
                        : Icons.comments_disabled_outlined),
                    title: Text(post.commentsDisabled
                        ? 'Bật bình luận'
                        : 'Tắt bình luận'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onUpdatePost(post,
                          {'commentsDisabled': !post.commentsDisabled});
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Xoá post',
                        style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDeletePost(post.id);
                    },
                  ),
                ]
              : [
                  ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Báo cáo vi phạm'),
                    onTap: () {
                      Navigator.pop(context);
                      showReportDialog(
                        context,
                        targetType: 'post',
                        targetId: post.id,
                      );
                    },
                  ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isHiddenOwner = post.isHidden && post.isOwnPost;

    return Opacity(
      opacity: isHiddenOwner ? 0.5 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  UserAvatar(url: post.avatarUrl, radius: 18, fallbackLabel: post.nickname),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              post.nickname ?? 'Người dùng',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (isHiddenOwner) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Đã ẩn',
                                    style: TextStyle(fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _timeAgo(post.createdAt),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showMenu(context),
                  ),
                ],
              ),
            ),
            // Images
            if (post.images.isNotEmpty)
              GestureDetector(
                onTap: () => widget.onTapPost(post),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    itemCount: post.images.length,
                    onPageChanged: (i) =>
                        setState(() => _currentImage = i),
                    itemBuilder: (_, i) => Image.network(
                      post.images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            // Image dots
            if (post.images.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    post.images.length,
                    (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentImage
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[300],
                      ),
                    ),
                  ),
                ),
              ),
            // Caption
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: GestureDetector(
                onTap: () => widget.onTapPost(post),
                child: post.caption.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.caption,
                            maxLines: _expanded ? null : 3,
                            overflow: _expanded
                                ? null
                                : TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (!_expanded && post.caption.length > 120)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _expanded = true),
                              child: Text(
                                'Xem thêm',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // Tags
            if (post.taggedStoreName != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/store/${post.taggedStoreId}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏪 ', style: TextStyle(fontSize: 13)),
                      Text(
                        post.taggedStoreName!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (post.taggedItemName != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/item/${post.taggedItemId}'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🍜 ', style: TextStyle(fontSize: 13)),
                      Text(
                        post.taggedItemName!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Actions bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  LikeButton(
                    isLiked: post.isLikedByMe,
                    count: post.likesCount,
                    onTap: () => widget.onToggleLike(post.id),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => widget.onTapPost(post),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${post.commentsCount}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
