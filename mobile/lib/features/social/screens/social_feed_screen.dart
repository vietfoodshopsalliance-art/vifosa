// lib/features/social/screens/social_feed_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_snackbar.dart';
import '../models/post_model.dart';
import '../social_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/comment_sheet.dart';
import 'create_post_screen.dart';

class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() => ref.read(feedProvider.notifier).fetchFeed();

  void _openCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    ).then((_) => ref.read(feedProvider.notifier).fetchFeed());
  }

  void _openComments(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(
        postId: post.id,
        commentsDisabled: post.commentsDisabled,
      ),
    );
  }

  void _onLike(Post post) {
    ref.read(feedProvider.notifier).toggleLike(post.id);
  }

  void _onReport(Post post) {
    _showReportDialog(targetType: 'post', targetId: post.id);
  }

  void _showReportDialog({
    required String targetType,
    required String targetId,
  }) {
    const reasons = ['spam', 'sai_su_that', 'quay_roi', 'lua_dao', 'khac'];
    const reasonLabels = {
      'spam': 'Spam',
      'sai_su_that': 'Sai sự thật',
      'quay_roi': 'Quấy rối',
      'lua_dao': 'Lừa đảo',
      'khac': 'Khác',
    };

    String selectedReason = reasons.first;
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Báo cáo vi phạm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lý do:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...reasons.map(
                (r) => RadioListTile<String>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(reasonLabels[r] ?? r),
                  value: r,
                  groupValue: selectedReason,
                  onChanged: (v) => setDialogState(() => selectedReason = v!),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Mô tả thêm (tuỳ chọn)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await DioClient.instance.post('/reports', data: {
                    'targetType': targetType,
                    'targetId': targetId,
                    'reason': selectedReason,
                    'description': descController.text.trim(),
                  });
                  if (mounted) {
                    AppSnackbar.success(context, 'Đã gửi báo cáo. Admin sẽ xem xét.');
                  }
                } catch (e) {
                  if (mounted) {
                    AppSnackbar.error(context, 'Lỗi: $e');
                  }
                }
              },
              child: const Text('Gửi báo cáo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cộng đồng'),
        actions: [
          IconButton(
            tooltip: 'Tạo bài viết',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _openCreatePost,
          ),
        ],
      ),
      body: _buildBody(feedState),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreatePost,
        tooltip: 'Tạo bài viết',
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildBody(FeedState feedState) {
    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(feedState.error ?? 'Có lỗi xảy ra'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _onRefresh,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: feedState.posts.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
        itemBuilder: (context, index) {
          if (index == feedState.posts.length) {
            return _buildFooter(feedState);
          }
          final post = feedState.posts[index];
          return PostCard(
            post: post,
            onToggleLike: (_) => _onLike(post),
            onTapPost: (_) => _openComments(post),
            onUpdatePost: (_, __) {},
            onDeletePost: (_) {},
          );
        },
      ),
    );
  }

  Widget _buildFooter(FeedState feedState) {
    if (feedState.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (!feedState.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Đã hiển thị hết bài viết',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// lib/features/social/screens/social_feed_screen.dart