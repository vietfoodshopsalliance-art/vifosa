// lib/features/home/widgets/store_card_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(
                url: store.coverImage ?? store.avatarImage, height: 100),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFFA000)),
                      const SizedBox(width: 2),
                      Text(
                        store.avgRating > 0
                            ? store.avgRating.toStringAsFixed(1)
                            : '—',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                      const Spacer(),
                      _OpenBadge(open: store.effectivelyOpen),
                    ],
                  ),
                  if (store.distanceKm != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${store.distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38),
                      ),
                    ),
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: _CoverImage(
                url: store.coverImage ?? store.avatarImage,
                height: 80,
                width: 100,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ),
                        _OpenBadge(open: store.effectivelyOpen),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.addressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: Color(0xFFFFA000)),
                        const SizedBox(width: 2),
                        Text(
                          store.avgRating > 0
                              ? store.avgRating.toStringAsFixed(1)
                              : '—',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
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
                          const Icon(Icons.place_outlined,
                              size: 13, color: Colors.black38),
                          Text(
                            '${store.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.black38),
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

  const _CoverImage({this.url, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(Icons.restaurant, color: Colors.black26, size: 28),
      ),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => placeholder,
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: open ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      ),
      child: Text(
        open ? 'Mở' : 'Đóng',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: open
              ? const Color(0xFF388E3C)
              : const Color(0xFFE53935),
        ),
      ),
    );
  }
}
