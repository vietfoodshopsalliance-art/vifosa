// mobile/lib/features/store_dashboard/screens/dashboard_reviews_tab.dart
//
// Tab "Reviews" trong Store Owner Dashboard.
// Highlight review chưa reply, badge "Mới" cho review trong 24h.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../reviews/data/review_model.dart';
import '../../reviews/review_providers.dart';

class DashboardReviewsTab extends ConsumerStatefulWidget {
  final String storeId;
  const DashboardReviewsTab({super.key, required this.storeId});

  @override
  ConsumerState<DashboardReviewsTab> createState() => _DashboardReviewsTabState();
}

class _DashboardReviewsTabState extends ConsumerState<DashboardReviewsTab> {
  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(storeReviewsProvider(widget.storeId));

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (result) {
        final unreplied = result.data.where((r) => r.reply == null).toList();
        final replied = result.data.where((r) => r.reply != null).toList();

        return ListView(
          children: [
            if (unreplied.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Chưa phản hồi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ...unreplied.map((r) => _OwnerReviewCard(
                    review: r,
                    onReplied: () => ref.invalidate(storeReviewsProvider(widget.storeId)),
                  )),
            ],
            if (replied.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Đã phản hồi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              ),
              ...replied.map((r) => _OwnerReviewCard(review: r, onReplied: null)),
            ],
          ],
        );
      },
    );
  }
}

class _OwnerReviewCard extends ConsumerStatefulWidget {
  final Review review;
  final VoidCallback? onReplied;

  const _OwnerReviewCard({required this.review, required this.onReplied});

  @override
  ConsumerState<_OwnerReviewCard> createState() => _OwnerReviewCardState();
}

class _OwnerReviewCardState extends ConsumerState<_OwnerReviewCard> {
  bool _replyMode = false;
  final _replyCtrl = TextEditingController();
  bool _loading = false;

  bool get _isNew =>
      DateTime.now().difference(widget.review.createdAt).inHours < 24;

  Future<void> _submitReply() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(reviewRepositoryProvider);
      await repo.createReply(widget.review.id, _replyCtrl.text.trim());
      widget.onReplied?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: stars + badge "Mới"
            Row(
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < widget.review.stars ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isNew)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Mới',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                const Spacer(),
                Text(
                  widget.review.author?.nickname ?? 'Ẩn danh',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (widget.review.comment.isNotEmpty) Text(widget.review.comment),

            // Reply existing
            if (widget.review.reply != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: Colors.grey.shade100,
                child: Text('Phản hồi: ${widget.review.reply!.text}'),
              ),

            // Reply button / form
            if (widget.review.reply == null) ...[
              const SizedBox(height: 8),
              if (!_replyMode)
                TextButton.icon(
                  icon: const Icon(Icons.reply),
                  label: const Text('Phản hồi'),
                  onPressed: () => setState(() => _replyMode = true),
                )
              else
                Column(
                  children: [
                    TextField(
                      controller: _replyCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Nhập phản hồi của bạn...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => setState(() => _replyMode = false),
                          child: const Text('Huỷ'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _loading ? null : _submitReply,
                          child: _loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Gửi'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }
}