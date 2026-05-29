// lib/features/store_detail/screens/store_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/models/store.dart';
import '../../../core/models/review.dart';
import '../../../core/utils/cloudinary_utils.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/item_card.dart';
import '../store_detail_provider.dart';
import '../../cart/screens/cart_screen.dart' show cartProvider;
import '../../auth/providers/auth_provider.dart';
import '../../order/screens/guest_checkout_screen.dart' show GuestCheckoutArgs;

class StoreDetailScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreDetailScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends ConsumerState<StoreDetailScreen> {
  final _coverPageCtrl = PageController();
  int _coverPage = 0;

  @override
  void dispose() {
    _coverPageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeDetailProvider(widget.storeId));
    final menuAsync  = ref.watch(storeMenuProvider(widget.storeId));
    final likedAsync = ref.watch(storeLikeProvider(widget.storeId));
    final totalItems = ref.watch(cartProvider).totalItems;
    final theme = Theme.of(context);

    return Scaffold(
      body: storeAsync.when(
        data: (store) => CustomScrollView(
          slivers: [
            // ── Cover carousel app bar ─────────────────────────────────
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: _CoverCarousel(
                  images: store.allCoverImages,
                  avatarImage: store.avatarImage,
                  pageCtrl: _coverPageCtrl,
                  currentPage: _coverPage,
                  onPageChanged: (p) => setState(() => _coverPage = p),
                  placeholderColor: theme.colorScheme.primary.withOpacity(0.3),
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
                      ref.read(storeLikeProvider(widget.storeId).notifier).toggle(),
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
                      onTap: () => _showReviews(context, ref, widget.storeId),
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
                      onTap: () => _showReviews(context, ref, widget.storeId),
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
                                storeId: widget.storeId,
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
                onPressed: () => ref.invalidate(storeDetailProvider(widget.storeId)),
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
          onPressed: () => _onCheckoutTap(
            context,
            ref,
            widget.storeId,
            storeAsync.valueOrNull?.name ?? '',
          ),
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

  void _onCheckoutTap(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    String storeName,
  ) {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (isAuthenticated) {
      context.go('/cart');
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      // Không có gì để đặt → đưa về login
      context.push('/login');
      return;
    }

    _showCheckoutChoiceSheet(context, ref, storeId, storeName);
  }

  void _showCheckoutChoiceSheet(
    BuildContext context,
    WidgetRef ref,
    String storeId,
    String storeName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bạn muốn tiếp tục như thế nào?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Đăng nhập để nhận ưu đãi thành viên và theo dõi đơn hàng dễ dàng hơn.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push('/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Đăng nhập'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final cart = ref.read(cartProvider);
                    final guestItems = cart.items
                        .map((i) => <String, dynamic>{
                              'itemId': i.itemId,
                              'name': i.name,
                              'qty': i.quantity,
                              'price': i.price,
                            })
                        .toList();
                    context.push(
                      '/guest-checkout',
                      extra: GuestCheckoutArgs(
                        storeId: cart.storeId ?? storeId,
                        storeName: cart.storeName ?? storeName,
                        items: guestItems,
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Tiếp tục không đăng nhập'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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

// ── Cover image carousel ──────────────────────────────────────────────────────

class _CoverCarousel extends StatelessWidget {
  final List<String> images;
  final String? avatarImage;
  final PageController pageCtrl;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final Color placeholderColor;

  const _CoverCarousel({
    required this.images,
    this.avatarImage,
    required this.pageCtrl,
    required this.currentPage,
    required this.onPageChanged,
    required this.placeholderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── PageView of cover images ───────────────────────────────────
        images.isEmpty
            ? Container(
                color: placeholderColor,
                child: const Icon(Icons.store, size: 72, color: Colors.white),
              )
            : PageView.builder(
                controller: pageCtrl,
                onPageChanged: onPageChanged,
                itemCount: images.length,
                itemBuilder: (_, i) => CachedNetworkImage(
                  imageUrl: cloudinaryDetail(images[i]),
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey.shade300),
                  errorWidget: (_, __, ___) => Container(
                    color: placeholderColor,
                    child: const Icon(Icons.store, size: 72, color: Colors.white),
                  ),
                ),
              ),

        // ── Avatar overlay ────────────────────────────────────────────
        if (avatarImage != null && avatarImage!.isNotEmpty)
          Positioned(
            bottom: images.length > 1 ? 28 : 12,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: cloudinaryThumb(avatarImage),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.grey.shade300,
                    child: const Icon(Icons.store, size: 28, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

        // ── Dot indicators ────────────────────────────────────────────
        if (images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentPage ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentPage
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
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
