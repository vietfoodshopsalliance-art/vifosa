// mobile/lib/features/social/widgets/comment_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vifosa/core/widgets/user_avatar.dart';

// ---------------------------------------------------------------------------
// Model nhẹ dùng nội bộ widget (thay bằng model thật khi có)
// ---------------------------------------------------------------------------

class CommentModel {
  const CommentModel({
    required this.id,
    required this.userId,
    required this.authorName,
    this.authorAvatar,
    required this.text,
    required this.createdAt,
    this.parentCommentId, // reply 1 cấp
  });

  final String id;
  final String userId;
  final String authorName;
  final String? authorAvatar;
  final String text;
  final DateTime createdAt;
  final String? parentCommentId;
}

// ---------------------------------------------------------------------------
// Provider đơn giản — thay bằng provider thật khi integrate API
// ---------------------------------------------------------------------------

// StateNotifierProvider giữ list comment của 1 post
final _commentsProvider =
    StateNotifierProvider.family<_CommentsNotifier, List<CommentModel>, String>(
  (ref, postId) => _CommentsNotifier(postId),
);

class _CommentsNotifier extends StateNotifier<List<CommentModel>> {
  _CommentsNotifier(this.postId) : super([]);

  final String postId;

  // TODO: gọi GET /posts/{postId}/comments
  Future<void> load() async {}

  // TODO: gọi POST /posts/{postId}/comments
  Future<void> addComment({required String text, String? parentCommentId}) async {
    // optimistic update — xoá khi có API thật
    final fake = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'me',
      authorName: 'Tôi',
      text: text,
      createdAt: DateTime.now(),
      parentCommentId: parentCommentId,
    );
    state = [...state, fake];
  }
}

// ---------------------------------------------------------------------------
// Hàm mở sheet từ bên ngoài
// ---------------------------------------------------------------------------

/// Gọi để hiển thị CommentSheet cho [postId].
/// [commentsDisabled] — true nếu chủ post tắt comment.
/// [isBlockedByOwner] — true nếu user hiện tại bị chặn.
void showCommentSheet(
  BuildContext context, {
  required String postId,
  bool commentsDisabled = false,
  bool isBlockedByOwner = false,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      child: CommentSheet(
        postId: postId,
        commentsDisabled: commentsDisabled,
        isBlockedByOwner: isBlockedByOwner,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Widget chính
// ---------------------------------------------------------------------------

class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({
    super.key,
    required this.postId,
    this.commentsDisabled = false,
    this.isBlockedByOwner = false,
  });

  final String postId;
  final bool commentsDisabled;
  final bool isBlockedByOwner;

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // load comments khi sheet mở
    Future.microtask(
      () => ref.read(_commentsProvider(widget.postId).notifier).load(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setReply(String commentId, String authorName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = authorName;
    });
    _focusNode.requestFocus();
  }

  void _clearReply() => setState(() {
        _replyToId = null;
        _replyToName = null;
      });

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await ref.read(_commentsProvider(widget.postId).notifier).addComment(
          text: text,
          parentCommentId: _replyToId,
        );
    _controller.clear();
    _clearReply();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(_commentsProvider(widget.postId));
    final mq = MediaQuery.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // handle bar
            const _SheetHandle(),

            // tiêu đề
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Bình luận',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),

            const Divider(height: 1),

            // danh sách comment
            Expanded(
              child: comments.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có bình luận nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: comments.length,
                      itemBuilder: (_, i) => _CommentTile(
                        comment: comments[i],
                        onReply: widget.commentsDisabled || widget.isBlockedByOwner
                            ? null
                            : () => _setReply(comments[i].id, comments[i].authorName),
                      ),
                    ),
            ),

            const Divider(height: 1),

            // input area
            _InputArea(
              controller: _controller,
              focusNode: _focusNode,
              replyToName: _replyToName,
              onCancelReply: _clearReply,
              onSend: _submit,
              sending: _sending,
              disabled: widget.commentsDisabled || widget.isBlockedByOwner,
              disabledHint: widget.isBlockedByOwner
                  ? 'Bạn không thể bình luận bài này'
                  : 'Chủ bài đã tắt bình luận',
              bottomPadding: mq.viewInsets.bottom + mq.padding.bottom,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.onReply});

  final CommentModel comment;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final isReply = comment.parentCommentId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 52 : 12,
        right: 12,
        top: 8,
        bottom: 4,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            url: comment.authorAvatar,
            fallbackLabel: comment.authorName,
            radius: isReply ? 14 : 18,  // size/2
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // tên + text
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(comment.text, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                // actions bên dưới bubble
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      Text(
                        _formatTime(comment.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      if (onReply != null) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            'Trả lời',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}

class _InputArea extends StatelessWidget {
  const _InputArea({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.sending,
    required this.disabled,
    required this.bottomPadding,
    this.replyToName,
    this.onCancelReply,
    this.disabledHint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyToName;
  final VoidCallback? onCancelReply;
  final Future<void> Function() onSend;
  final bool sending;
  final bool disabled;
  final String? disabledHint;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // banner reply
          if (replyToName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    'Đang trả lời $replyToName',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // text field + nút gửi
          disabled
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    disabledHint ?? 'Không thể bình luận',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Viết bình luận...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // nút gửi
                    InkWell(
                      onTap: sending ? null : onSend,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sending ? Colors.grey[300] : Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: sending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// mobile/lib/features/social/widgets/comment_sheet.dart