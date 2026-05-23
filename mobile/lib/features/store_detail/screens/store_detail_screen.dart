// lib/features/store_detail/screens/store_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/models/store.dart';
import '../../../core/models/review.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/item_card.dart';
import '../store_detail_provider.dart';
import '../../cart/screens/cart_screen.dart' show cartProvider;

class StoreDetailScreen extends ConsumerWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeAsync = ref.watch(storeDetailProvider(storeId));
    final menuAsync  = ref.watch(storeMenuProvider(storeId));
    final likedAsync = ref.watch(storeLikeProvider(storeId));
    final totalItems = ref.watch(cartProvider).totalItems;
    final theme = Theme.of(context);

    return Scaffold(
      body: storeAsync.when(
        data: (store) => CustomScrollView(
          slivers: [
            // ── Cover image app bar ────────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover image
                    store.coverImage != null && store.coverImage!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: store.coverImage!,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.colorScheme.primary.withOpacity(0.3),
                            child: const Icon(Icons.store,
                                size: 72, color: Colors.white),
                          ),
                    // Avatar overlay — góc dưới bên trái
                    if (store.avatarImage != null &&
                        store.avatarImage!.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 6)
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: store.avatarImage!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.grey.shade300,
                                child: const Icon(Icons.store,
                                    size: 28, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    likedAsync.valueOrNull == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: likedAsync.valueOrNull == true
                        ? Colors.red
                        : Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(storeLikeProvider(storeId).notifier).toggle(),
                ),
              ],
            ),

            // ── Store info ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                        StatusBadge(
                          label: _statusLabel(store.displayStatus),
                          backgroundColor: _statusColor(store.displayStatus),
                          textColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (store.description != null)
                      Text(
                        store.description!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _showReviews(context, ref, storeId),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            store.stats.avgRating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${store.stats.totalReviews} đánh giá)',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    if (store.addressText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.addressText,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (store.phone != null && store.phone!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            store.phone!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),
                    GestureDetector(
                      onTap: () => _showReviews(context, ref, storeId),
                      child: const Row(
                        children: [
                          Icon(Icons.rate_review_outlined, size: 18),
                          SizedBox(width: 6),
                          Text('Xem đánh giá'),
                          Spacer(),
                          Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Menu ──────────────────────────────────────────────────
            menuAsync.when(
              data: (categories) {
                if (categories.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Chưa có món',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final cat = categories[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Text(
                              cat.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...cat.items.map((item) => ItemCard(
                                item: item,
                                storeId: storeId,
                                storeName: store.name,
                                storeStatus: store.displayStatus,
                              )),
                        ],
                      );
                    },
                    childCount: categories.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (_, __) => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Không thể tải menu')),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không thể tải thông tin cửa hàng'),
              TextButton(
                onPressed: () => ref.invalidate(storeDetailProvider(storeId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Badge(
        isLabelVisible: totalItems > 0,
        label: Text('$totalItems', style: const TextStyle(color: Colors.white, fontSize: 11)),
        backgroundColor: Colors.red,
        alignment: AlignmentDirectional.topEnd,
        child: FloatingActionButton.extended(
          onPressed: () => context.go('/cart'),
          icon: const Icon(Icons.shopping_cart),
          label: const Text('Xem giỏ hàng'),
        ),
      ),
    );
  }

  String _statusLabel(StoreStatus status) {
    switch (status) {
      case StoreStatus.open:             return 'Đang mở';
      case StoreStatus.preOrder:         return 'Đặt trước';
      case StoreStatus.emergencyClosed:  return 'Tạm đóng';
      case StoreStatus.suspended:        return 'Đóng cửa';
    }
  }

  Color _statusColor(StoreStatus status) {
    switch (status) {
      case StoreStatus.open:            return const Color(0xFF4CAF50);
      case StoreStatus.preOrder:        return const Color(0xFFFFC107);
      case StoreStatus.emergencyClosed: return const Color(0xFFF44336);
      case StoreStatus.suspended:       return const Color(0xFF9E9E9E);
    }
  }

  void _showReviews(BuildContext context, WidgetRef ref, String id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewsSheet(storeId: id),
    );
  }
}

// ── Reviews bottom sheet ──────────────────────────────────────────────────────

class _ReviewsSheet extends ConsumerStatefulWidget {
  final String storeId;
  const _ReviewsSheet({required this.storeId});

  @override
  ConsumerState<_ReviewsSheet> createState() => _ReviewsSheetState();
}

class _ReviewsSheetState extends ConsumerState<_ReviewsSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeReviewsProvider(widget.storeId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Đánh giá',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${state.reviews.length} đánh giá',
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Rating filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _chip(context, label: 'Tất cả', value: null,
                      current: state.ratingFilter),
                  ...List.generate(
                    5,
                    (i) => _chip(context,
                        label: '${i + 1}★',
                        value: i + 1,
                        current: state.ratingFilter),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),

            // List
            Expanded(
              child: state.reviews.isEmpty && !state.isLoading
                  ? const Center(
                      child: Text(
                        'Chưa có đánh giá nào',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollEndNotification &&
                            n.metrics.pixels >=
                                n.metrics.maxScrollExtent - 150) {
                          ref
                              .read(storeReviewsProvider(widget.storeId)
                                  .notifier)
                              .fetchNextPage();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount:
                            state.reviews.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 16),
                        itemBuilder: (_, i) {
                          if (i >= state.reviews.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            );
                          }
                          return _ReviewCard(review: state.reviews[i]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required int? value,
    required int? current,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: value == current,
        onSelected: (_) => ref
            .read(storeReviewsProvider(widget.storeId).notifier)
            .fetchFirstPage(rating: value),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name =
        review.isAnonymous ? 'Người dùng ẩn danh' : (review.nickname ?? '?');
    final dateStr =
        DateFormat('dd/MM/yyyy').format(review.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name + date
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (!review.isAnonymous && review.avatar != null)
                    ? NetworkImage(review.avatar!)
                    : null,
                child: (!review.isAnonymous && review.avatar == null)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 14),
                      )
                    : (review.isAnonymous
                        ? const Icon(Icons.person_outline,
                            size: 18, color: Colors.grey)
                        : null),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Stars
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

          // Comment
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment, style: const TextStyle(fontSize: 13)),
          ],

          // Images
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: review.images[i],
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Store reply
          if (review.reply != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phản hồi từ quán',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(review.reply!.text,
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
