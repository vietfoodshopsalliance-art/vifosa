// lib/core/widgets/store_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/store.dart';
import 'status_badge.dart';

/// Card quán dùng ở Home feed (horizontal & vertical), Search, Favorites.
class StoreCard extends StatelessWidget {
  final Store store;
  final VoidCallback onTap;
  /// True → layout ngang (horizontal scroll). False → layout dọc (list).
  final bool compact;

  const StoreCard({
    super.key,
    required this.store,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Ẩn quán emergencyClosed / suspended khỏi feed (double-check phía UI)
    if (store.isHiddenFromFeed) return const SizedBox.shrink();

    return compact ? _buildCompact(context) : _buildFull(context);
  }

  // ── Compact (horizontal scroll) ────────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _coverImage(height: 100),
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
                  _ratingRow(),
                  const SizedBox(height: 4),
                  StatusBadge.store(store.displayStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Full (vertical list) ───────────────────────────────────────────────────
  Widget _buildFull(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            _coverImage(width: 100, height: 100),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    _ratingRow(),
                    const SizedBox(height: 6),
                    StatusBadge.store(store.displayStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _coverImage({double? width, double? height}) {
    final url = store.coverImage;
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.storefront, color: Colors.grey),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) =>
          Container(color: Colors.grey[200], width: width, height: height),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[200],
        width: width,
        height: height,
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }

  Widget _ratingRow() {
    final rating = store.stats.avgRating;
    final dist = store.distanceKm;
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFBC02D)),
        const SizedBox(width: 2),
        Text(
          rating > 0 ? rating.toStringAsFixed(1) : 'Mới',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        if (dist != null) ...[
          const SizedBox(width: 8),
          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
          Text(
            '${dist.toStringAsFixed(1)} km',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}