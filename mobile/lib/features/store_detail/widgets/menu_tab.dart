// lib/features/store_detail/widgets/menu_tab.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/category.dart';
import '../../../core/models/menu_item.dart';
import '../../../features/cart/cart_provider.dart';
import '../store_detail_provider.dart';

class MenuTab extends ConsumerWidget {
  final String storeId;
  final String storeName;

  const MenuTab({super.key, required this.storeId, required this.storeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(storeMenuProvider(storeId));

    return menuAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi tải menu: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('Chưa có món nào'));
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: categories.length,
          itemBuilder: (context, catIndex) {
            final cat = categories[catIndex];
            return _CategorySection(
              category: cat,
              storeId: storeId,
              storeName: storeName,
            );
          },
        );
      },
    );
  }
}

// ── Category section với sticky header ───────────────────────────────────────
class _CategorySection extends StatelessWidget {
  final Category category;
  final String storeId;
  final String storeName;

  const _CategorySection({
    required this.category,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sticky-style category header
        Container(
          width: double.infinity,
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            category.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        ...category.items.map(
          (item) => _MenuItemTile(
            item: item,
            storeId: storeId,
            storeName: storeName,
          ),
        ),
      ],
    );
  }
}

// ── MenuItemTile ──────────────────────────────────────────────────────────────
class _MenuItemTile extends ConsumerWidget {
  final MenuItem item;
  final String storeId;
  final String storeName;

  const _MenuItemTile({
    required this.item,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSoldOut = item.stock != null && item.stock == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ảnh món
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: isSoldOut ? 0.5 : 1.0,
              child: CachedNetworkImage(
                imageUrl: item.imageUrl ?? '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: Colors.grey.shade200, width: 80, height: 80),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.fastfood, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Thông tin
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSoldOut ? Colors.grey : null,
                  ),
                ),
                if (item.description.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatPrice(item.price),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    // Like món
                    _LikeItemButton(item: item),
                    const SizedBox(width: 8),
                    // Nút thêm vào giỏ / Hết hàng
                    isSoldOut
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Hết hàng',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          )
                        : _AddToCartButton(
                            item: item,
                            storeId: storeId,
                            storeName: storeName,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}đ';
  }
}

// ── Like item button ──────────────────────────────────────────────────────────
class _LikeItemButton extends ConsumerStatefulWidget {
  final MenuItem item;

  const _LikeItemButton({required this.item});

  @override
  ConsumerState<_LikeItemButton> createState() => _LikeItemButtonState();
}

class _LikeItemButtonState extends ConsumerState<_LikeItemButton> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.isLiked;
  }

  Future<void> _toggle() async {
    setState(() => _isLiked = !_isLiked);
    try {
      if (_isLiked) {
        await ref.read(cartProvider.notifier).likeItem(widget.item.id);
      } else {
        await ref.read(cartProvider.notifier).unlikeItem(widget.item.id);
      }
    } catch (_) {
      setState(() => _isLiked = !_isLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Icon(
        _isLiked ? Icons.favorite : Icons.favorite_border,
        color: _isLiked ? Colors.red : Colors.grey,
        size: 20,
      ),
    );
  }
}

// ── Add to cart button ────────────────────────────────────────────────────────
class _AddToCartButton extends ConsumerWidget {
  final MenuItem item;
  final String storeId;
  final String storeName;

  const _AddToCartButton({
    required this.item,
    required this.storeId,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _handleAdd(context, ref),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 18),
      ),
    );
  }

  Future<void> _handleAdd(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);

    // Pre-order nhắc nhở
    if ((await ref.read(storeDetailProvider(storeId).future)).status ==
        'pre_order') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Đặt trước'),
          content: const Text(
              'Đơn này sẽ xử lý khi quán mở cửa. Bạn vẫn muốn thêm?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đồng ý'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // Giỏ từ quán khác
    if (cart.isNotEmpty && cart.storeId != storeId) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Xoá giỏ hàng?'),
          content: Text(
            'Giỏ hàng của bạn đang có món từ ${cart.storeName}. Xoá và thêm món mới?',
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

    ref.read(cartProvider.notifier).addItem(item, context,
        storeId: storeId, storeName: storeName);
  }
}
