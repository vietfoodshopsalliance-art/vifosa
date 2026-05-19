// mobile/lib/features/reviews/screens/store_reviews_tab.dart
//
// Được nhúng trong Store Detail Screen dưới dạng Tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/review_model.dart';
import '../review_providers.dart';

class StoreReviewsTab extends ConsumerStatefulWidget {
  final String storeId;
  const StoreReviewsTab({super.key, required this.storeId});

  @override
  ConsumerState<StoreReviewsTab> createState() => _StoreReviewsTabState();
}

class _StoreReviewsTabState extends ConsumerState<StoreReviewsTab> {
  String _sort = 'newest';

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(storeReviewsProvider(widget.storeId));

    return reviewsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (result) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildStats(result)),
          SliverToBoxAdapter(child: _buildSortBar()),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _ReviewCard(review: result.data[i]),
              childCount: result.data.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(StoreReviewsResult result) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                result.avgRating.toStringAsFixed(1),
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < result.avgRating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
              Text('${result.totalReviews} đánh giá',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: ['5', '4', '3', '2', '1'].map((star) {
                final count = result.distribution[star] ?? 0;
                final pct = result.totalReviews > 0
                    ? count / result.totalReviews
                    : 0.0;
                return Row(
                  children: [
                    Text('$star⭐', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: LinearProgressIndicator(value: pct, color: Colors.amber),
                    ),
                    const SizedBox(width: 4),
                    Text('$count', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('Sắp xếp: ', style: TextStyle(fontWeight: FontWeight.bold)),
          ...[
            ('newest', 'Mới nhất'),
            ('highest', 'Cao nhất'),
            ('lowest', 'Thấp nhất'),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(item.$2),
                  selected: _sort == item.$1,
                  onSelected: (_) => setState(() => _sort = item.$1),
                ),
              )),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author + stars
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: review.author?.avatar != null
                      ? NetworkImage(review.author!.avatar!)
                      : null,
                  child: review.author?.avatar == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.author?.nickname ?? 'Người dùng ẩn danh',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < review.stars ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(review.createdAt),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Comment
            if (review.comment.isNotEmpty) Text(review.comment),

            // Images
            if (review.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(review.images[i], width: 80, fit: BoxFit.cover),
                  ),
                ),
              ),
            ],

            // Order info
            if (review.orderInfo != null) ...[
              const SizedBox(height: 4),
              Text(
                'Đơn ${review.orderInfo!['code']}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],

            // Reply từ quán
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
                    const Text('Phản hồi từ quán:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(review.reply!.text),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}