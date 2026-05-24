// lib/features/store_dashboard/reviews/store_reviews_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'reply_dialog.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final storeReviewsProvider =
    FutureProvider.family.autoDispose<List<dynamic>, String>(
  (ref, storeId) async {
    final dio = ref.read(dioClientProvider);
    final res = await dio.dio.get(ApiEndpoints.storeReviews(storeId));
    return (res.data['reviews'] as List<dynamic>);
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class StoreReviewsScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreReviewsScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreReviewsScreen> createState() =>
      _StoreReviewsScreenState();
}

class _StoreReviewsScreenState extends ConsumerState<StoreReviewsScreen> {
  int? _starFilter;        // null = all
  bool? _repliedFilter;   // null = all, true = replied, false = unreplied

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(storeReviewsProvider(widget.storeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá')),
      body: Column(
        children: [
          // ─ Filters ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Star filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                          label: 'Tất cả',
                          selected: _starFilter == null,
                          onTap: () => setState(() => _starFilter = null)),
                      for (int s = 5; s >= 1; s--)
                        _FilterChip(
                            label: '$s★',
                            selected: _starFilter == s,
                            onTap: () =>
                                setState(() => _starFilter = s)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Reply filter
                Row(
                  children: [
                    _FilterChip(
                        label: 'Tất cả',
                        selected: _repliedFilter == null,
                        onTap: () =>
                            setState(() => _repliedFilter = null)),
                    _FilterChip(
                        label: 'Chưa phản hồi',
                        selected: _repliedFilter == false,
                        onTap: () =>
                            setState(() => _repliedFilter = false)),
                    _FilterChip(
                        label: 'Đã phản hồi',
                        selected: _repliedFilter == true,
                        onTap: () =>
                            setState(() => _repliedFilter = true)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 12),

          // ─ List ──────────────────────────────────────────────────────────
          Expanded(
            child: reviewsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (reviews) {
                var filtered = reviews.cast<Map<String, dynamic>>();

                if (_starFilter != null) {
                  filtered = filtered
                      .where((r) => r['stars'] == _starFilter)
                      .toList();
                }
                if (_repliedFilter != null) {
                  filtered = filtered.where((r) {
                    final hasReply = r['reply'] != null;
                    return _repliedFilter! ? hasReply : !hasReply;
                  }).toList();
                }

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Không có đánh giá nào',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(
                      storeReviewsProvider(widget.storeId).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ReviewCard(
                      storeId: widget.storeId,
                      review: filtered[i],
                      onRefresh: () => ref.refresh(
                          storeReviewsProvider(widget.storeId).future),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ReviewCard ───────────────────────────────────────────────────────────────

class _ReviewCard extends ConsumerWidget {
  final String storeId;
  final Map<String, dynamic> review;
  final VoidCallback onRefresh;

  const _ReviewCard({
    required this.storeId,
    required this.review,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = review['stars'] as int? ?? 5;
    final userName = review['nickname'] as String? ?? 'Người dùng ẩn danh';
    final comment = review['comment'] as String? ?? '';
    final images = (review['images'] as List?)?.cast<String>() ?? [];
    final orderId = review['orderId'] as String?;
    final orderCode = review['orderCode'] as String?;
    final createdAt = review['createdAt'] as String?;
    final storeReply = review['reply'] as Map<String, dynamic>?;
    final avatarUrl = review['avatar'] as String?;

    final replyText = storeReply?['text'] as String?;
    final replyCreatedAt = storeReply?['at'] as String?;
    final bool canEdit = replyCreatedAt != null &&
        DateTime.now()
            .difference(DateTime.parse(replyCreatedAt))
            .inHours <
            24;
    Duration? editRemaining;
    if (canEdit) {
      final deadline = DateTime.parse(replyCreatedAt)
          .add(const Duration(hours: 24));
      editRemaining = deadline.difference(DateTime.now());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 14,
                              color: i < rating
                                  ? Colors.amber
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (createdAt != null)
                  Text(
                    DateFormat('dd/MM/yyyy')
                        .format(DateTime.parse(createdAt)),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
            // Order code
            if (orderId != null && orderCode != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.push('/order/$orderId'),
                child: Text(
                  'Đơn #$orderCode',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(comment, style: const TextStyle(fontSize: 13)),
            ],
            // Images
            if (images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(images[i],
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],
            const Divider(height: 16),
            // Store reply section
            if (storeReply != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phản hồi của quán:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(replyText ?? '',
                        style: const TextStyle(fontSize: 13)),
                    if (canEdit && editRemaining != null) ...[
                      const SizedBox(height: 4),
                      _EditCountdown(remaining: editRemaining),
                    ],
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Sửa phản hồi',
                        style: TextStyle(fontSize: 13)),
                    onPressed: () => _showReplyDialog(
                      context,
                      ref,
                      initialReply: replyText,
                      isEdit: true,
                    ),
                  ),
                ),
              ],
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text('Phản hồi',
                      style: TextStyle(fontSize: 13)),
                  onPressed: () =>
                      _showReplyDialog(context, ref, isEdit: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(
    BuildContext context,
    WidgetRef ref, {
    String? initialReply,
    required bool isEdit,
  }) {
    final reviewId = review['_id'] as String;
    showDialog(
      context: context,
      builder: (_) => ReplyDialog(
        initialReply: initialReply,
        onSave: (text) async {
          await DioClient.instance.patch(
            ApiEndpoints.storeReviewReply(storeId, reviewId),
            data: {'text': text},
          );
          onRefresh();
        },
      ),
    );
  }
}

class _EditCountdown extends StatefulWidget {
  final Duration remaining;
  const _EditCountdown({required this.remaining});

  @override
  State<_EditCountdown> createState() => _EditCountdownState();
}

class _EditCountdownState extends State<_EditCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.remaining;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() => _remaining -= const Duration(seconds: 30));
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
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    return Text(
      'Thời gian sửa còn: ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}',
      style:
          const TextStyle(fontSize: 11, color: Colors.orange),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
