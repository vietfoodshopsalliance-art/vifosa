// lib/features/home/widgets/store_card_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/services/image_service.dart';
import '../models/store_card.dart';

// ── Compact horizontal card ───────────────────────────────────────────────────

class StoreCardHorizontal extends StatelessWidget {
  final StoreCard store;
  final VoidCallback? onTap;

  const StoreCardHorizontal({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 175,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with gradient overlay showing store name + badge
            Stack(
              children: [
                _CoverImage(
                  url: store.coverImage ?? store.avatarImage,
                  height: 115,
                ),
                // Gradient at bottom of image
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Store name and open badge overlaid on image
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _OpenBadge(open: store.effectivelyOpen),
                    ],
                  ),
                ),
              ],
            ),
            // Rating + distance strip
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Color(0xFFF4B400),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    store.avgRating > 0
                        ? store.avgRating.toStringAsFixed(1)
                        : '—',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (store.totalReviews > 0) ...[
                    const SizedBox(width: 2),
                    Text(
                      '(${store.totalReviews})',
                      style: const TextStyle(fontSize: 11, color: Colors.black38),
                    ),
                  ],
                  if (store.distanceKm != null) ...[
                    const Spacer(),
                    const Icon(Icons.near_me_outlined,
                        size: 12, color: Colors.black38),
                    const SizedBox(width: 2),
                    Text(
                      '${store.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45),
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
}

// ── Full-width vertical card ──────────────────────────────────────────────────

class StoreCardVertical extends StatelessWidget {
  final StoreCard store;
  final VoidCallback? onTap;

  const StoreCardVertical({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            // Square thumbnail
            SizedBox(
              width: 90,
              height: 90,
              child: _CoverImage(
                url: store.coverImage ?? store.avatarImage,
                height: 90,
                width: 90,
                isThumb: true,
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _OpenBadge(open: store.effectivelyOpen),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 12, color: Colors.black38),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            store.addressText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Color(0xFFF4B400)),
                        const SizedBox(width: 3),
                        Text(
                          store.avgRating > 0
                              ? store.avgRating.toStringAsFixed(1)
                              : '—',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (store.totalReviews > 0) ...[
                          const SizedBox(width: 2),
                          Text(
                            '(${store.totalReviews})',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black38),
                          ),
                        ],
                        if (store.distanceKm != null) ...[
                          const Spacer(),
                          const Icon(Icons.near_me_outlined,
                              size: 12, color: Color(0xFFF4B400)),
                          const SizedBox(width: 2),
                          Text(
                            '${store.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  final String? url;
  final double height;
  final double? width;
  final bool isThumb;

  const _CoverImage({
    this.url,
    required this.height,
    this.width,
    this.isThumb = true,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      color: const Color(0xFFFFF8E1),
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
          color: const Color(0xFFF4B400).withValues(alpha: 0.5),
          size: 30,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    final transformed =
        isThumb ? ImageService.thumbnail(url!) : ImageService.detail(url!);

    return CachedNetworkImage(
      imageUrl: transformed,
      width: width,
      height: height,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => _ShimmerBox(width: width, height: height),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;

  const _ShimmerBox({this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _ctrl.value, 0),
            end: Alignment(0 + 2 * _ctrl.value, 0),
            colors: const [
              Color(0xFFEEEEEE),
              Color(0xFFFAFAFA),
              Color(0xFFEEEEEE),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: open
            ? const Color(0xFFF4B400).withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.08),
      ),
      child: Text(
        open ? 'Mở' : 'Đóng',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: open ? const Color(0xFFB8860B) : Colors.black45,
        ),
      ),
    );
  }
}
