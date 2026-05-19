// mobile/lib/features/reviews/screens/my_reviews_screen.dart
//
// Màn hình "Đánh giá của tôi" trong Profile.
// Trong 24h: hiện nút Sửa / Xoá.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/review_model.dart';
import '../review_providers.dart';

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myReviewsAsync = ref.watch(myReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá của tôi')),
      body: myReviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          final reviews = (data['data'] as List)
              .map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList();
          if (reviews.isEmpty) {
            return const Center(child: Text('Bạn chưa có đánh giá nào'));
          }
          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (ctx, i) => _MyReviewCard(
              review: reviews[i],
              onChanged: () => ref.invalidate(myReviewsProvider),
            ),
          );
        },
      ),
    );
  }
}

class _MyReviewCard extends ConsumerWidget {
  final Review review;
  final VoidCallback onChanged;

  const _MyReviewCard({required this.review, required this.onChanged});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá đánh giá?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Row(
          children: [
            ...List.generate(
              5,
              (i) => Icon(
                i < review.stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Text(
          review.comment.isEmpty ? '(Không có bình luận)' : review.comment,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: review.canDelete
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () {
                      // Navigate to edit screen
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => EditReviewScreen(review: review)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: () => _delete(context, ref),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}