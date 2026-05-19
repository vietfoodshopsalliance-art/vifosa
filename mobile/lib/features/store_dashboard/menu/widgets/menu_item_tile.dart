// lib/features/store_dashboard/menu/widgets/menu_item_tile.dart

import 'package:flutter/material.dart';
import '../providers/menu_provider.dart';

class MenuItemTile extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onQuickStock;

  const MenuItemTile({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onQuickStock,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = item.stock != null && item.stock == 0;
    final isPaused = item.status == 'paused';
    final isClosed = item.status == 'closed';
    final isDimmed = isPaused || isClosed || isOutOfStock;

    return Dismissible(
      key: ValueKey('tile_${item.id}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        color: const Color(0xFFFF9800).withOpacity(0.15),
        child: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFFFF9800)),
            SizedBox(width: 8),
            Text('Cập nhật tồn kho',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    color: Color(0xFFFF9800),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        onQuickStock();
        return false; // không thực sự dismiss
      },
      child: Opacity(
        opacity: isDimmed ? 0.55 : 1.0,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: item.images.isNotEmpty
                      ? Image.network(
                          '${item.images.first}?tx=w_120,f_auto,q_auto',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage,
                        )
                      : _placeholderImage,
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isClosed)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.lock_outline,
                                  size: 14, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPrice(item.price),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Badges row
                      Wrap(
                        spacing: 6,
                        children: [
                          if (isOutOfStock)
                            const _Badge(
                                label: 'Hết hàng',
                                color: Color(0xFFFF3B30)),
                          if (isPaused)
                            const _Badge(
                                label: 'Tạm ẩn',
                                color: Color(0xFF8E8E93)),
                          if (isClosed)
                            const _Badge(
                                label: 'Ngừng bán',
                                color: Color(0xFF636366)),
                          if (item.stock != null && item.stock! > 0)
                            _Badge(
                              label: 'Còn ${item.stock}',
                              color: const Color(0xFF34C759),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Quick actions
                Column(
                  children: [
                    // Toggle active/paused
                    if (!isClosed)
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: item.status == 'active',
                          activeThumbColor: const Color(0xFF34C759),
                          onChanged: (_) => onToggleStatus(),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget get _placeholderImage => Container(
        width: 64,
        height: 64,
        color: const Color(0xFFF0F0F0),
        child: const Icon(Icons.fastfood_outlined,
            color: Color(0xFFCCCCCC), size: 28),
      );

  String _formatPrice(int price) {
    final parts = price.toString().split('');
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.write('.');
      result.write(parts[i]);
    }
    return '$resultđ';
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store_dashboard/menu/widgets/category_drag_tile.dart
// ─────────────────────────────────────────────────────────────────────────────

class CategoryDragTile extends StatelessWidget {
  final MenuCategory category;
  final VoidCallback onEdit;

  const CategoryDragTile({
    super.key,
    required this.category,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.drag_indicator_rounded,
              color: Color(0xFFFF6B35), size: 20),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              color: Color(0xFF999999), size: 20),
          onPressed: onEdit,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/widgets/customer_item_card.dart
// ─────────────────────────────────────────────────────────────────────────────

class CustomerItemCard extends ConsumerWidget {
  final MenuItem item;
  final String storeId;
  final bool canOrder;

  const CustomerItemCard({
    super.key,
    required this.item,
    required this.storeId,
    required this.canOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartQty = ref.watch(cartItemQtyProvider(item.id));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: canOrder ? () => _showItemDetail(context, ref) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.images.isNotEmpty
                    ? Image.network(
                        '${item.images.first}?tx=w_200,f_auto,q_auto',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder,
                      )
                    : _placeholder,
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          _formatPrice(item.price),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                        const Spacer(),
                        if (canOrder)
                          _QuantityControl(
                            quantity: cartQty,
                            onAdd: () => ref
                                .read(cartProvider(storeId).notifier)
                                .add(item),
                            onRemove: () => ref
                                .read(cartProvider(storeId).notifier)
                                .remove(item.id),
                          )
                        else
                          const Text(
                            'Quá xa',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get _placeholder => Container(
        width: 88,
        height: 88,
        color: const Color(0xFFF5F5F5),
        child: const Icon(Icons.fastfood_outlined,
            color: Color(0xFFDDDDDD), size: 36),
      );

  String _formatPrice(int price) {
    final parts = price.toString().split('');
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.write('.');
      result.write(parts[i]);
    }
    return '$resultđ';
  }

  void _showItemDetail(BuildContext context, WidgetRef ref) {
    // Mở bottom sheet chi tiết món với ảnh lớn — có thể expand thành full screen
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(
        item: item,
        storeId: storeId,
        canOrder: canOrder,
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _QuantityControl({
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (quantity == 0) {
      return GestureDetector(
        onTap: onAdd,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 20),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.remove,
                color: Color(0xFF666666), size: 18),
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            quantity.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _ItemDetailSheet extends ConsumerWidget {
  final MenuItem item;
  final String storeId;
  final bool canOrder;

  const _ItemDetailSheet({
    required this.item,
    required this.storeId,
    required this.canOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartQty = ref.watch(cartItemQtyProvider(item.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Ảnh
              if (item.images.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: Image.network(
                    '${item.images.first}?tx=w_800,f_auto,q_auto',
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: const Center(
                    child: Icon(Icons.fastfood_outlined,
                        size: 64, color: Color(0xFFDDDDDD)),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatPrice(item.price),
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          color: Color(0xFF666666),
                          height: 1.6,
                        ),
                      ),
                    ],
                    if (item.soldCount != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              size: 16, color: Color(0xFFFF6B35)),
                          const SizedBox(width: 4),
                          Text(
                            'Đã bán ${item.soldCount!.last30d} lần trong 30 ngày qua',
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Add to cart button
                    if (canOrder)
                      Row(
                        children: [
                          _QuantityControl(
                            quantity: cartQty,
                            onAdd: () => ref
                                .read(cartProvider(storeId).notifier)
                                .add(item),
                            onRemove: () => ref
                                .read(cartProvider(storeId).notifier)
                                .remove(item.id),
                          ),
                          const Spacer(),
                          if (cartQty > 0)
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Xem giỏ hàng',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPrice(int price) {
    final parts = price.toString().split('');
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.write('.');
      result.write(parts[i]);
    }
    return '$resultđ';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/widgets/store_header.dart
// ─────────────────────────────────────────────────────────────────────────────

class StoreHeader extends StatelessWidget {
  final StoreModel store;
  const StoreHeader({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ảnh bìa
        Stack(
          children: [
            store.coverImage != null
                ? Image.network(
                    '${store.coverImage}?tx=w_800,f_auto,q_auto',
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 220,
                    color: const Color(0xFFFF6B35).withOpacity(0.15),
                    child: const Center(
                      child: Icon(Icons.storefront_outlined,
                          size: 72, color: Color(0xFFFF6B35)),
                    ),
                  ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Status badge
            Positioned(
              bottom: 14,
              left: 16,
              child: _StoreBadge(store: store),
            ),
          ],
        ),

        // Store info
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  if (store.rating != null)
                    _InfoChip(
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFFFCC00),
                      label: store.rating!.toStringAsFixed(1),
                    ),
                  if (store.distanceKm != null)
                    _InfoChip(
                      icon: Icons.near_me_rounded,
                      iconColor: const Color(0xFF007AFF),
                      label: '${store.distanceKm!.toStringAsFixed(1)} km',
                    ),
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    iconColor: const Color(0xFF34C759),
                    label: store.openHours ?? 'Chưa cập nhật',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreBadge extends StatelessWidget {
  final StoreModel store;
  const _StoreBadge({required this.store});

  @override
  Widget build(BuildContext context) {
    final isOpen = store.isOpen ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFF34C759) : Colors.grey[700],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'Đang mở' : 'Đã đóng',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _InfoChip(
      {required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: Color(0xFF555555))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/widgets/menu_category_tab_bar.dart
// ─────────────────────────────────────────────────────────────────────────────

class MenuCategoryTabBar extends StatelessWidget {
  final List<MenuCategory> categories;
  final TabController controller;
  final void Function(int) onCategoryTap;

  const MenuCategoryTabBar({
    super.key,
    required this.categories,
    required this.controller,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      indicatorColor: const Color(0xFFFF6B35),
      indicatorWeight: 3,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: const Color(0xFFFF6B35),
      unselectedLabelColor: const Color(0xFF888888),
      labelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 14),
      unselectedLabelStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w500,
          fontSize: 14),
      tabs: categories
          .map((c) => Tab(text: c.name))
          .toList(),
      onTap: onCategoryTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/cart/widgets/cart_bottom_bar.dart
// ─────────────────────────────────────────────────────────────────────────────

class CartBottomBar extends ConsumerWidget {
  final String storeId;
  const CartBottomBar({super.key, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider(storeId));
    if (cart.isEmpty) return const SizedBox.shrink();

    final totalQty = cart.values.fold(0, (sum, item) => sum + item.quantity);
    final totalPrice =
        cart.values.fold(0, (sum, item) => sum + item.quantity * item.price);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          // Navigate to cart/checkout — module 05
          Navigator.pushNamed(context, '/cart', arguments: storeId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$totalQty',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Xem giỏ hàng',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              _formatPrice(totalPrice),
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    final parts = price.toString().split('');
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) result.write('.');
      result.write(parts[i]);
    }
    return '$resultđ';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// lib/features/store/widgets/distance_warning_banner.dart
// ─────────────────────────────────────────────────────────────────────────────

class DistanceWarningBanner extends StatelessWidget {
  final double distanceKm;
  final bool isBlocked; // > 25km

  const DistanceWarningBanner({
    super.key,
    required this.distanceKm,
    required this.isBlocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isBlocked
            ? const Color(0xFFFF3B30).withOpacity(0.1)
            : const Color(0xFFFF9800).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked
              ? const Color(0xFFFF3B30).withOpacity(0.3)
              : const Color(0xFFFF9800).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBlocked
                ? Icons.location_off_rounded
                : Icons.warning_amber_rounded,
            color: isBlocked
                ? const Color(0xFFFF3B30)
                : const Color(0xFFFF9800),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBlocked
                  ? 'Quán này cách bạn ${distanceKm.toStringAsFixed(1)} km — vượt quá giới hạn đặt hàng 25 km.'
                  : 'Quán cách bạn ${distanceKm.toStringAsFixed(1)} km — phí giao có thể cao.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isBlocked
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFFCC7A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
