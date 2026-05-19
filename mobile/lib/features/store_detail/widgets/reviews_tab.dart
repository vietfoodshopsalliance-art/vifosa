// lib/features/store_detail/widgets/reviews_tab.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/review.dart';
import '../store_detail_provider.dart';

class ReviewsTab extends ConsumerStatefulWidget {
  final String storeId;

  const ReviewsTab({super.key, required this.storeId});

  @override
  ConsumerState<ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends ConsumerState<ReviewsTab> {
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
      ref.read(storeReviewsProvider(widget.storeId).notifier).fetchNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeReviewsProvider(widget.storeId));

    return Column(
      children: [
        // ── Rating filter chips ───────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _RatingChip(
                label: 'Tất cả',
                value: null,
                current: state.ratingFilter,
                storeId: widget.storeId,
              ),
              ...List.generate(
                5,
                (i) => _RatingChip(
                  label: '${5 - i}★',
                  value: 5 - i,
                  current: state.ratingFilter,
                  storeId: widget.storeId,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Reviews list ─────────────────────────────────────────────────
        Expanded(
          child: state.reviews.isEmpty && state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.reviews.isEmpty
                  ? const Center(child: Text('Chưa có đánh giá nào'))
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount:
                          state.reviews.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i >= state.reviews.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _ReviewCard(review: state.reviews[i]);
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Rating filter chip ───────────────────────────────────────────────────────
class _RatingChip extends ConsumerWidget {
  final String label;
  final int? value;
  final int? current;
  final String storeId;

  const _RatingChip({
    required this.label,
    required this.value,
    required this.current,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
            color: selected ? Colors.white : null, fontSize: 12),
        onSelected: (_) {
          ref
              .read(storeReviewsProvider(storeId).notifier)
              .fetchFirstPage(rating: value);
        },
      ),
    );
  }
}

// ── ReviewCard ───────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final isAnonymous = review.userId == null || review.nickname == null;
    final displayName = isAnonymous ? 'Người dùng ẩn danh' : review.nickname!;
    final dateStr = DateFormat('dd/MM/yyyy').format(review.createdAt);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: avatar, tên, sao, ngày
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (!isAnonymous && review.avatar != null)
                    ? CachedNetworkImageProvider(review.avatar!)
                    : null,
                child:
                    (isAnonymous || review.avatar == null)
                        ? const Icon(Icons.person, size: 20, color: Colors.grey)
                        : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(dateStr,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Comment
          Text(review.comment, style: const TextStyle(fontSize: 13)),
          // Ảnh
          if (review.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _showFullscreen(context, review.images, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: review.images[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ],
          // Store reply
          if (review.storeReply?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.only(left: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phản hồi của quán',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.storeReply!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullscreen(
      BuildContext context, List<String> images, int initial) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(
          images: images,
          initialIndex: initial,
        ),
      ),
    );
  }
}

// ── Fullscreen image viewer ──────────────────────────────────────────────────
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(imageUrl: widget.images[i]),
          ),
        ),
      ),
    );
  }
}