// lib/features/social/widgets/comment_tile.dart

import 'package:flutter/material.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/comment_model.dart';
import 'like_button.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool isReply;
  final void Function(Comment) onReply;
  final void Function(String commentId, String? parentId) onToggleLike;
  final void Function(Comment) onReport;
  final void Function(Comment) onBlockCommenter;
  final bool isOwnPost;

  const CommentTile({
    super.key,
    required this.comment,
    this.isReply = false,
    required this.onReply,
    required this.onToggleLike,
    required this.onReport,
    required this.onBlockCommenter,
    required this.isOwnPost,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!comment.isOwnComment && isOwnPost)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Chặn người này bình luận'),
                onTap: () {
                  Navigator.pop(context);
                  onBlockCommenter(comment);
                },
              ),
            if (!comment.isOwnComment)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Báo cáo vi phạm'),
                onTap: () {
                  Navigator.pop(context);
                  onReport(comment);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indent = isReply ? 48.0 : 0.0;
    return Padding(
      padding: EdgeInsets.only(left: indent, top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            url: comment.avatarUrl,
            radius: isReply ? 14 : 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.nickname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (!comment.isOwnComment)
                      GestureDetector(
                        onTap: () => _showMenu(context),
                        child: Icon(Icons.more_horiz,
                            size: 18, color: Colors.grey[500]),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(comment.content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _timeAgo(comment.createdAt),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 16),
                    LikeButton(
                      isLiked: comment.isLikedByMe,
                      count: comment.likesCount,
                      iconSize: 15,
                      onTap: () => onToggleLike(comment.id, comment.parentId),
                    ),
                    const SizedBox(width: 16),
                    if (!isReply)
                      GestureDetector(
                        onTap: () => onReply(comment),
                        child: Text(
                          'Trả lời',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                // Replies (1 cấp)
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...comment.replies.map(
                    (r) => CommentTile(
                      comment: r,
                      isReply: true,
                      onReply: onReply,
                      onToggleLike: onToggleLike,
                      onReport: onReport,
                      onBlockCommenter: onBlockCommenter,
                      isOwnPost: isOwnPost,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}