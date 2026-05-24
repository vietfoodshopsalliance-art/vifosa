// lib/features/reviews/screens/my_reviews_screen.dart

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/review_model.dart';
import '../review_providers.dart';

class MyReviewsScreen extends ConsumerStatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  ConsumerState<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends ConsumerState<MyReviewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đánh giá'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tôi đã viết'),
            Tab(text: 'Nhận về'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyGivenReviewsTab(),
          _MyReceivedReviewsTab(),
        ],
      ),
    );
  }
}

// ─── Tab: reviews tôi đã viết cho quán ───────────────────────────────────────

class _MyGivenReviewsTab extends ConsumerWidget {
  const _MyGivenReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReviewsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(myReviewsProvider),
      ),
      data: (reviews) {
        if (reviews.isEmpty) {
          return const _EmptyView(
            icon: Icons.rate_review_outlined,
            message: 'Bạn chưa đánh giá quán nào',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _GivenReviewTile(
            review: reviews[i],
            onChanged: () => ref.invalidate(myReviewsProvider),
          ),
        );
      },
    );
  }
}

// ─── Tab: reviews tôi nhận về từ quán ────────────────────────────────────────

class _MyReceivedReviewsTab extends ConsumerWidget {
  const _MyReceivedReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReviewsReceivedProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(myReviewsReceivedProvider),
      ),
      data: (result) {
        if (result.reviews.isEmpty) {
          return const _EmptyView(
            icon: Icons.inbox_outlined,
            message: 'Chưa có đánh giá nào từ quán',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: result.reviews.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) => _ReceivedReviewTile(
            review: result.reviews[i],
            onChanged: () => ref.invalidate(myReviewsReceivedProvider),
          ),
        );
      },
    );
  }
}

// ─── Tile: review tôi đã viết ─────────────────────────────────────────────────

class _GivenReviewTile extends ConsumerWidget {
  final MyReview review;
  final VoidCallback onChanged;

  const _GivenReviewTile({required this.review, required this.onChanged});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá đánh giá?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(reviewRepositoryProvider).deleteReview(review.id);
      onChanged();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: review.storeId != null
          ? () => context.push('/store/${review.storeId}')
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: review.storeAvatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: review.storeAvatarUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _storePlaceholder,
                      errorWidget: (_, __, ___) => _storePlaceholder,
                    )
                  : _storePlaceholder,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.storeName ?? 'Quán đã xóa',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      if (review.canDelete) ...[
                        if (review.canEdit)
                          _ActionIcon(
                            icon: Icons.edit_outlined,
                            onTap: () {
                              // TODO: navigate to EditReviewScreen
                            },
                          ),
                        const SizedBox(width: 4),
                        _ActionIcon(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          onTap: () => _confirmDelete(context, ref),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < review.stars ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (review.comment.isNotEmpty)
                    Text(
                      review.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (review.images.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: review.images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: review.images[i],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (review.orderCode != null)
                        Text(
                          'Đơn ${review.orderCode}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      if (review.isAnonymous) ...[
                        if (review.orderCode != null) const SizedBox(width: 6),
                        const Text(
                          '· Ẩn danh',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _fmtDate(review.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (review.reply != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phản hồi của quán:',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          Text(review.reply!.text,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget get _storePlaceholder => Container(
        width: 52,
        height: 52,
        color: Colors.grey.shade200,
        child: const Icon(Icons.store, color: Colors.grey),
      );
}

// ─── Tile: review nhận về từ quán ────────────────────────────────────────────

class _ReceivedReviewTile extends ConsumerStatefulWidget {
  final ReceivedReview review;
  final VoidCallback onChanged;

  const _ReceivedReviewTile({required this.review, required this.onChanged});

  @override
  ConsumerState<_ReceivedReviewTile> createState() =>
      _ReceivedReviewTileState();
}

class _ReceivedReviewTileState extends ConsumerState<_ReceivedReviewTile> {
  void _showReplyDialog({String? initialText}) {
    final ctrl = TextEditingController(text: initialText ?? '');
    bool loading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title:
              Text(initialText != null ? 'Sửa phản hồi' : 'Phản hồi đánh giá'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Nhập phản hồi của bạn...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setDlgState(() => loading = true);
                      try {
                        await ref
                            .read(reviewRepositoryProvider)
                            .replyToReceivedReview(
                              reviewId: widget.review.id,
                              text: text,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onChanged();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Lỗi: $e')));
                        }
                      } finally {
                        if (ctx.mounted) setDlgState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Gửi'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final authorName = r.isAnonymous ? 'Ẩn danh' : (r.fromNickname ?? 'Chủ quán');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar + tên + sao + ngày
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage:
                    !r.isAnonymous && r.fromAvatar != null
                        ? NetworkImage(r.fromAvatar!)
                        : null,
                child: (r.isAnonymous || r.fromAvatar == null)
                    ? const Icon(Icons.storefront, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < r.stars
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color:
                              i < r.stars ? Colors.amber : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _fmtDate(r.createdAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),

          // Order code
          if (r.orderCode != null) ...[
            const SizedBox(height: 4),
            Text('Đơn ${r.orderCode}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],

          // Comment
          if (r.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.comment, style: const TextStyle(fontSize: 13)),
          ],

          // Images
          if (r.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(r.images[i],
                      width: 64, height: 64, fit: BoxFit.cover),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // My reply
          if (r.myReply != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phản hồi của bạn:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(r.myReply!.text,
                      style: const TextStyle(fontSize: 13)),
                  if (r.canEditReply) ...[
                    const SizedBox(height: 4),
                    _EditCountdown(
                      deadline: r.myReply!.editedAt != null
                          ? r.myReply!.editedAt!.add(const Duration(hours: 24))
                          : (widget.review.editedAt ?? widget.review.createdAt)
                              .add(const Duration(hours: 24)),
                    ),
                  ],
                ],
              ),
            ),
            if (r.canEditReply) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Sửa phản hồi',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () =>
                      _showReplyDialog(initialText: r.myReply!.text),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ),
            ],
          ] else if (r.canReply) ...[
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.reply, size: 14),
                label: const Text('Phản hồi', style: TextStyle(fontSize: 12)),
                onPressed: () => _showReplyDialog(),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Countdown widget (rolling 24h) ──────────────────────────────────────────

class _EditCountdown extends StatefulWidget {
  final DateTime deadline;
  const _EditCountdown({required this.deadline});

  @override
  State<_EditCountdown> createState() => _EditCountdownState();
}

class _EditCountdownState extends State<_EditCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.deadline.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() =>
            _remaining = widget.deadline.difference(DateTime.now()));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    return Text(
      'Còn ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} để sửa',
      style: const TextStyle(fontSize: 11, color: Colors.orange),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text('Không tải được: $message', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, size: 18, color: color ?? Colors.grey.shade600),
    );
  }
}

String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
