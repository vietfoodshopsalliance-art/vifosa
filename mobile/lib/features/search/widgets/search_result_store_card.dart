// lib/features/search/widgets/search_result_store_card.dart
// Card kết quả tìm kiếm: thông tin quán + các món match (max 3)

import 'package:flutter/material.dart';
import '../../search/providers/search_provider.dart';
import '../../../shared/widgets/status_badge.dart';

class SearchResultStoreCard extends StatelessWidget {
  final SearchResultItem storeResult;
  final VoidCallback onStoreTab;
  final VoidCallback onViewAllItems;

  const SearchResultStoreCard({
    super.key,
    required this.storeResult,
    required this.onStoreTab,
    required this.onViewAllItems,
  });

  @override
  Widget build(BuildContext context) {
    final store = storeResult.store;
    final items = storeResult.matchedItems;

    return GestureDetector(
      onTap: onStoreTab,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Store header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      store.avatarImage ?? '',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFEEEEEE),
                        child: const Icon(Icons.storefront_outlined,
                            color: Color(0xFFBDBDBD), size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                store.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StatusBadge.store(
                              store.emergencyClosed
                                  ? StoreStatus.emergencyClosed
                                  : store.isOpen
                                      ? StoreStatus.open
                                      : StoreStatus.preorder,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: Color(0xFFFFB300)),
                            const SizedBox(width: 2),
                            Text(
                              store.avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF555555)),
                            ),
                            const SizedBox(width: 8),
                            if (store.distanceKm != null) ...[
                              const Icon(Icons.place_outlined,
                                  size: 12, color: Color(0xFF9E9E9E)),
                              const SizedBox(width: 2),
                              Text(
                                '${store.distanceKm!.toStringAsFixed(1)}km',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF9E9E9E)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Món match ─────────────────────────────────────────
            if (items.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              ...items.take(3).map((item) => _MatchedItemRow(item: item)),
              if (items.length > 3)
                _ViewMoreRow(onTap: onViewAllItems, count: items.length),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchedItemRow extends StatelessWidget {
  final MatchedItem item;

  const _MatchedItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              item.image ?? '',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 40,
                color: const Color(0xFFEEEEEE),
                child: const Icon(Icons.restaurant_menu_outlined,
                    size: 18, color: Color(0xFFBDBDBD)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatPrice(item.price),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE8472A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price) {
    // Format VND: 65000 → "65.000đ"
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return '${buf.toString()}đ';
  }
}

class _ViewMoreRow extends StatelessWidget {
  final VoidCallback onTap;
  final int count;

  const _ViewMoreRow({required this.onTap, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF5F3),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        child: Text(
          'Xem thêm ${count - 3} món của quán này',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFE8472A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
