// lib/core/widgets/item_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/category.dart';
import '../models/store.dart' show StoreStatus;
import '../../features/cart/screens/cart_screen.dart'
    show cartProvider, CartItem, CartState;

// ---------------------------------------------------------------------------
// Formatter
// ---------------------------------------------------------------------------
final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// ---------------------------------------------------------------------------
// ItemCard
// ---------------------------------------------------------------------------
// Props:
//   item        — CategoryItem (typed, từ storeMenuProvider)
//   storeId     — để thêm vào cart
//   storeName   — để gắn vào CartItem
//   storeStatus — StoreStatus enum; emergencyClosed thì ẩn nút thêm
// ---------------------------------------------------------------------------

class ItemCard extends ConsumerWidget {
  final CategoryItem item;
  final String storeId;
  final String storeName;
  final StoreStatus storeStatus;

  const ItemCard({
    super.key,
    required this.item,
    required this.storeId,
    required this.storeName,
    required this.storeStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // open và preOrder đều cho thêm vào giỏ (preOrder bắt buộc CK, xử lý ở checkout)
    final canOrder = storeStatus != StoreStatus.emergencyClosed && item.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Thumbnail ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.primaryImage != null
                ? CachedNetworkImage(
                    imageUrl: item.primaryImage!,
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
                  item.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.description!,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _vnd.format(item.price),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.stock != null && item.stock! <= 10 && item.stock! > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Còn ${item.stock}',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ],
                    if (!item.isAvailable) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.stock == 0 ? 'Hết hàng' : 'Tạm ngưng',
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
            _AddRemoveButton(item: item, storeId: storeId, storeName: storeName)
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
// _AddRemoveButton — inline quantity stepper kết nối cartProvider
// ---------------------------------------------------------------------------

class _AddRemoveButton extends ConsumerWidget {
  final CategoryItem item;
  final String storeId;
  final String storeName;

  const _AddRemoveButton({
    required this.item,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final qty = cart.items.fold<int>(
      0,
      (sum, e) => e.itemId == item.id ? e.quantity : sum,
    );

    if (qty == 0) {
      return _circleBtn(
        icon: Icons.add,
        color: Theme.of(context).colorScheme.primary,
        onTap: () => _handleAdd(context, ref, cart),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleBtn(
          icon: Icons.remove,
          color: Colors.grey.shade400,
          onTap: () => ref.read(cartProvider.notifier).updateQty(item.id, qty - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '$qty',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        _circleBtn(
          icon: Icons.add,
          color: Theme.of(context).colorScheme.primary,
          onTap: () => _handleAdd(context, ref, cart),
        ),
      ],
    );
  }

  Future<void> _handleAdd(BuildContext context, WidgetRef ref, CartState cart) async {
    if (cart.items.isNotEmpty && cart.storeId != storeId) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xoá giỏ hàng?'),
          content: Text(
            'Giỏ hàng đang có món từ ${cart.storeName}. Xoá và thêm món mới?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá và thêm'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      ref.read(cartProvider.notifier).clearCart();
    }

    ref.read(cartProvider.notifier).addItem(
      CartItem(
        itemId: item.id,
        name: item.name,
        price: item.price.toDouble(),
        imageUrl: item.primaryImage,
        storeId: storeId,
        storeName: storeName,
        quantity: 1,
        stock: item.stock,
      ),
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
