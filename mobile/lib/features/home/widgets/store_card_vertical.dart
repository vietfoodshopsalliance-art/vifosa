// lib/features/home/widgets/store_card_vertical.dart
// Card hiển thị dọc trong nhóm "Gần bạn" (nhóm 6)

import 'package:flutter/material.dart';
import '../../home/providers/home_feed_provider.dart';
import 'package:vifosa/core/widgets/status_badge.dart';

class StoreCardVertical extends StatelessWidget {
  final StoreCardModel store;

  const StoreCardVertical({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to store detail
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Thumbnail ────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Stack(
                children: [
                  Image.network(
                    store.coverImage,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 110,
                      height: 110,
                      color: const Color(0xFFEEEEEE),
                      child: const Icon(Icons.storefront_outlined,
                          color: Color(0xFFBDBDBD), size: 36),
                    ),
                  ),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    Text(
                      store.address.text,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF9E9E9E)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFB300)),
                        const SizedBox(width: 2),
                        Text(
                          store.stats.avgRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${store.stats.totalReviews})',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF9E9E9E)),
                        ),
                        const Spacer(),
                        _DistanceRow(distanceKm: store.distanceKm),
                      ],
                    ),

                    if ((store.distanceKm ?? 0) > 10) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 12, color: Color(0xFFF57F17)),
                            const SizedBox(width: 4),
                            Text(
                              '${store.distanceKm?.toStringAsFixed(1)}km — Xa hơn bình thường',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFF57F17),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _DistanceRow extends StatelessWidget {
  final double? distanceKm;

  const _DistanceRow({this.distanceKm});

  @override
  Widget build(BuildContext context) {
    if (distanceKm == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.place_outlined,
            size: 12, color: Color(0xFF9E9E9E)),
        const SizedBox(width: 2),
        Text(
          '${distanceKm!.toStringAsFixed(1)}km',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
        ),
      ],
    );
  }
}
