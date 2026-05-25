// lib/features/store_detail/screens/item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/models/category.dart';
import '../../../core/models/store.dart' show StoreStatus;
import '../../cart/screens/cart_screen.dart' show cartProvider, CartItem, CartState;
import '../store_detail_provider.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class ItemDetailScreen extends ConsumerWidget {
  final CategoryItem item;
  final String storeId;
  final String storeName;
  final StoreStatus storeStatus;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.storeId,
    required this.storeName,
    required this.storeStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(itemLikeProvider((item.id, item.likeId)));
    final cart = ref.watch(cartProvider);
    final canOrder = storeStatus != StoreStatus.emergencyClosed && item.isAvailable;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: item.primaryImage != null
                  ? CachedNetworkImage(
                      imageUrl: item.primaryImage!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
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
                onPressed: () => ref
                    .read(itemLikeProvider((item.id, item.likeId)).notifier)
                    .toggle(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên + giá
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _vnd.format(item.price),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  // Tình trạng hàng
                  if (!item.isAvailable) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        item.stock == 0 ? 'Hết hàng' : 'Tạm ngưng',
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ] else if (item.stock != null &&
                      item.stock! <= 10 &&
                      item.stock! > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Còn ${item.stock} suất',
                      style: const TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ],

                  // Mô tả
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Mô tả',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description!,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                  ],

                  // Tên quán
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.store_outlined,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        storeName,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: canOrder
              ? ElevatedButton.icon(
                  onPressed: () => _handleAdd(context, ref, cart),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Thêm vào giỏ hàng'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                )
              : ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52)),
                  child: const Text('Không thể đặt món này'),
                ),
        ),
      ),
    );
  }

  Future<void> _handleAdd(
      BuildContext context, WidgetRef ref, CartState cart) async {
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
    if (context.mounted) Navigator.pop(context);
  }

  Widget _imagePlaceholder() => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.fastfood, size: 72, color: Colors.grey),
        ),
      );

}
