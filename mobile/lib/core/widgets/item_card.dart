// lib/core/widgets/item_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';

// ---------------------------------------------------------------------------
// Formatter
// ---------------------------------------------------------------------------
final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// ---------------------------------------------------------------------------
// ItemCard
// ---------------------------------------------------------------------------
// Dùng trong StoreDetailScreen, nhận raw Map từ storeDetailProvider (FutureProvider)
// hoặc CategoryItem từ storeMenuProvider.
//
// Props:
//   item        — Map<String, dynamic> từ API (khớp với CategoryItem.fromJson)
//   storeId     — để thêm vào cart
//   storeStatus — 'open' | 'pre_order' | 'closed'; closed thì ẩn nút thêm
// ---------------------------------------------------------------------------

class ItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final String storeId;
  final String storeStatus;

  const ItemCard({
    super.key,
    required this.item,
    required this.storeId,
    required this.storeStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsed = CategoryItem.fromJson(item);
    final theme = Theme.of(context);
    final canOrder = storeStatus != 'closed' && parsed.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: parsed.primaryImage != null
                ? CachedNetworkImage(
                    imageUrl: parsed.primaryImage!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),

          const SizedBox(width: 12),

          // ── Info ───────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parsed.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (parsed.description != null && parsed.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    parsed.description!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _vnd.format(parsed.price),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (parsed.stock != null && parsed.stock! <= 10 && parsed.stock! > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Còn ${parsed.stock}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ],
                    if (!parsed.isAvailable) ...[
                      const SizedBox(width: 8),
                      Text(
                        parsed.stock == 0 ? 'Hết hàng' : 'Tạm ngưng',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Add button / counter ───────────────────────────────────────
          if (canOrder)
            _AddRemoveButton(itemId: parsed.id, storeId: storeId, item: parsed)
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        color: Colors.grey.shade200,
        child: const Icon(Icons.fastfood, color: Colors.grey, size: 32),
      );
}

// ---------------------------------------------------------------------------
// _AddRemoveButton — inline quantity stepper
// Kết nối với cartProvider (stub module 05).
// Thay thế bằng provider thực khi module 05 hoàn chỉnh.
// ---------------------------------------------------------------------------

class _AddRemoveButton extends ConsumerWidget {
  final String itemId;
  final String storeId;
  final CategoryItem item;

  const _AddRemoveButton({
    required this.itemId,
    required this.storeId,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: replace with real cartProvider(storeId) when module 05 is done
    // final cart = ref.watch(cartProvider(storeId));
    // final qty = cart[itemId]?.quantity ?? 0;
    const qty = 0; // stub

    if (qty == 0) {
      return _circleBtn(
        icon: Icons.add,
        color: Theme.of(context).colorScheme.primary,
        onTap: () {
          // ref.read(cartProvider(storeId).notifier).add(item);
        },
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleBtn(
          icon: Icons.remove,
          color: Colors.grey.shade400,
          onTap: () {
            // ref.read(cartProvider(storeId).notifier).remove(itemId);
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '$qty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _circleBtn(
          icon: Icons.add,
          color: Theme.of(context).colorScheme.primary,
          onTap: () {
            // ref.read(cartProvider(storeId).notifier).add(item);
          },
        ),
      ],
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

// lib/core/widgets/item_card.dart