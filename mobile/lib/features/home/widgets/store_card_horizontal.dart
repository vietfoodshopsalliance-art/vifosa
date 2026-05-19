// lib/features/home/widgets/store_card_horizontal.dart
// Card hiển thị ngang trong horizontal scroll (nhóm 1,3,4,5)

import 'package:flutter/material.dart';
import '../../home/providers/home_feed_provider.dart';
import 'package:vifosa/core/widgets/status_badge.dart';

class StoreCardHorizontal extends StatelessWidget {
  final StoreCardModel store;

  const StoreCardHorizontal({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to store detail
      },
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover image ──────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Stack(
                children: [
                  Image.network(
                    store.coverImage,
                    width: 170,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 170,
                      height: 110,
                      color: const Color(0xFFEEEEEE),
                      child: const Icon(Icons.storefront_outlined,
                          color: Color(0xFFBDBDBD), size: 36),
                    ),
                  ),
                  // Status badge overlay — chỉ hiện khi không phải open
                  if (store.status != StoreStatus.open)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: StatusBadge.store(store.status),
                    ),
                ],
              ),
            ),

            // ── Info ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFFB300)),
                      const SizedBox(width: 2),
                      Text(
                        store.stats.avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF555555)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${store.stats.totalReviews})',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  _DistanceRow(distanceKm: store.distanceKm),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Distance row ──────────────────────────────────────────────────

class _DistanceRow extends StatelessWidget {
  final double? distanceKm;

  const _DistanceRow({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    if (distanceKm == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.place_outlined, size: 12, color: Color(0xFF9E9E9E)),
        const SizedBox(width: 2),
        Text(
          '${distanceKm!.toStringAsFixed(1)}km',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
      ],
    );
  }
}
