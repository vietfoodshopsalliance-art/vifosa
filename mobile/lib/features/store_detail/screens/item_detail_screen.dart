// lib/features/store_detail/screens/item_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/category.dart';
import '../../../core/models/store.dart' show StoreStatus;
import '../../cart/screens/cart_screen.dart' show cartProvider, CartItem, CartState;
import '../store_detail_provider.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// ── Cloudinary URL helpers ────────────────────────────────────────────────────

// Chèn transform vào URL Cloudinary: /upload/ → /upload/{t}/
String _clTransform(String url, String t) {
  const m = '/upload/';
  final i = url.indexOf(m);
  if (i == -1) return url;
  final after = url.substring(i + m.length);
  if (after.startsWith('$t/')) return url; // đã có transform này
  return '${url.substring(0, i + m.length)}$t/$after';
}

// 800px, format + quality auto — dùng cho detail view
String _clDetail(String url) => _clTransform(url, 'f_auto,q_auto,w_800');

// 20px cực nhỏ + blur — tải gần như tức thì, dùng làm placeholder
String _clBlur(String url) => _clTransform(url, 'w_20,q_10,e_blur:400');

// ── Placeholder box ───────────────────────────────────────────────────────────

Widget _placeholderBox() => Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.fastfood, size: 72, color: Colors.grey),
      ),
    );

// ── ItemDetailScreen ──────────────────────────────────────────────────────────

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

    final qtyInCart = cart.items
        .where((e) => e.itemId == item.id)
        .fold(0, (sum, e) => sum + e.quantity);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App bar với ảnh ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _ImageSwiper(images: item.images),
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

          // ── Nội dung ─────────────────────────────────────────────────────
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
                  if (storeName.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.store_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          storeName,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 128),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Điều khiển số lượng / thêm giỏ
              if (!canOrder)
                ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: const Text('Không thể đặt món này'),
                )
              else if (qtyInCart == 0)
                ElevatedButton.icon(
                  onPressed: () => _handleAdd(context, ref, cart),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Thêm vào giỏ hàng'),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                )
              else
                _QuantityControl(
                  qty: qtyInCart,
                  atStockLimit:
                      item.stock != null && qtyInCart >= item.stock!,
                  onDecrease: () => ref
                      .read(cartProvider.notifier)
                      .updateQty(item.id, qtyInCart - 1),
                  onIncrease: () => _handleAdd(context, ref, cart),
                ),

              const SizedBox(height: 8),

              // Nút vào cửa hàng
              OutlinedButton.icon(
                onPressed: () => context.push('/store/$storeId'),
                icon: const Icon(Icons.storefront_outlined, size: 18),
                label: const Text('Mua tiếp tại cửa hàng'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: Color(0xFFF4B400)),
                  foregroundColor: const Color(0xFFF4B400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
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
  }
}

// ── Image swiper ──────────────────────────────────────────────────────────────

class _ImageSwiper extends StatefulWidget {
  final List<String> images;
  const _ImageSwiper({required this.images});

  @override
  State<_ImageSwiper> createState() => _ImageSwiperState();
}

class _ImageSwiperState extends State<_ImageSwiper> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return _placeholderBox();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── PageView ───────────────────────────────────────────────────────
        PageView.builder(
          controller: _ctrl,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => _CldImage(url: widget.images[i]),
        ),

        // ── Dots indicator (chỉ hiện khi nhiều hơn 1 ảnh) ─────────────────
        if (widget.images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: _DotsIndicator(
              count: widget.images.length,
              current: _page,
            ),
          ),
      ],
    );
  }
}

// ── Cloudinary image với blur-up placeholder ──────────────────────────────────

class _CldImage extends StatelessWidget {
  final String url;
  const _CldImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _clDetail(url),
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      // Blur-up: tải ảnh 20px mờ trước (< 1KB), hiện ngay trong lúc ảnh full load
      placeholder: (_, __) => CachedNetworkImage(
        imageUrl: _clBlur(url),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (_, __) =>
            Container(color: Colors.grey.shade200), // chưa có gì: xám
        errorWidget: (_, __, ___) => Container(color: Colors.grey.shade200),
      ),
      errorWidget: (_, __, ___) => _placeholderBox(),
    );
  }
}

// ── Dots indicator ────────────────────────────────────────────────────────────

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotsIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: i == current ? 18 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: i == current ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

// ── Quantity control ──────────────────────────────────────────────────────────

class _QuantityControl extends StatelessWidget {
  final int qty;
  final bool atStockLimit;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityControl({
    required this.qty,
    required this.atStockLimit,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF4B400), width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Nút giảm / xóa
          InkWell(
            onTap: onDecrease,
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(9)),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Icon(
                qty == 1 ? Icons.delete_outline : Icons.remove,
                color:
                    qty == 1 ? Colors.red : const Color(0xFFF4B400),
                size: 20,
              ),
            ),
          ),

          // Số lượng — nhấn vào cũng tăng giống nút +
          Expanded(
            child: InkWell(
              onTap: atStockLimit ? null : onIncrease,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$qty',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  Text(
                    'trong giỏ',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),

          // Nút tăng
          InkWell(
            onTap: atStockLimit ? null : onIncrease,
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(9)),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Icon(
                Icons.add,
                color: atStockLimit
                    ? Colors.grey.shade300
                    : const Color(0xFFF4B400),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
