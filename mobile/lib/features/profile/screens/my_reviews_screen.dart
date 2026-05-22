// lib/features/profile/screens/my_reviews_screen.dart
// Màn hình xem các review tôi đã viết cho quán (reviews-given)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class _MyReview {
  final String id;
  final String storeName;
  final String? storeAvatarUrl;
  final String? storeId;
  final String orderCode;
  final int stars;
  final String comment;
  final List<String> images;
  final bool isAnonymous;
  final DateTime createdAt;

  const _MyReview({
    required this.id,
    required this.storeName,
    this.storeAvatarUrl,
    this.storeId,
    required this.orderCode,
    required this.stars,
    required this.comment,
    required this.images,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory _MyReview.fromJson(Map<String, dynamic> json) {
    final store = json['toEntityId'] as Map<String, dynamic>?;
    final order = json['orderId'] as Map<String, dynamic>?;
    return _MyReview(
      id: json['_id'] as String? ?? '',
      storeName: store?['name'] as String? ?? 'Quán đã xóa',
      storeAvatarUrl: store?['avatarImage'] as String?,
      storeId: store?['_id'] as String?,
      orderCode: order?['code'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String? ?? '',
      images: ((json['images'] as List?) ?? []).cast<String>(),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _myReviewsProvider = FutureProvider<List<_MyReview>>((ref) async {
  final res = await DioClient.instance.get('/me/reviews-given');
  final list = (res.data['reviews'] as List? ?? []);
  return list.map((e) => _MyReview.fromJson(e as Map<String, dynamic>)).toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quán đã đánh giá')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Không tải được: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(_myReviewsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (reviews) {
          if (reviews.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Bạn chưa đánh giá quán nào', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _ReviewTile(review: reviews[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _ReviewTile extends StatelessWidget {
  final _MyReview review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: review.storeId != null
          ? () => context.push('/store/${review.storeId}')
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: review.storeAvatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: review.storeAvatarUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder,
                      errorWidget: (_, __, ___) => _placeholder,
                    )
                  : _placeholder,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store name
                  Text(
                    review.storeName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),

                  // Stars
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < review.stars ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    )),
                  ),
                  const SizedBox(height: 4),

                  // Comment
                  if (review.comment.isNotEmpty)
                    Text(
                      review.comment,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),

                  // Images thumbnail row
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
                      Text(
                        'Đơn ${review.orderCode}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (review.isAnonymous) ...[
                        const SizedBox(width: 8),
                        const Text(
                          '· Ẩn danh',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _formatDate(review.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget get _placeholder => Container(
        width: 52,
        height: 52,
        color: Colors.grey.shade200,
        child: const Icon(Icons.store, color: Colors.grey),
      );

  static String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
