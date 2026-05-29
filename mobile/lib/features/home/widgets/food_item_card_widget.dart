// lib/features/home/widgets/food_item_card_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/liked_items_provider.dart';
import '../../../core/utils/cloudinary_utils.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/food_item_card.dart';

class FoodItemCardWidget extends StatelessWidget {
  final FoodItemCard item;
  final VoidCallback? onTap;

  const FoodItemCardWidget({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final feature = item.feature;
    final oldPriceVal = item.oldPrice;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hình nổi 3D ──────────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Ảnh với bóng đổ 3D lên background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.14),
                          blurRadius: 22,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _ItemImage(url: item.image),
                    ),
                  ),
                ),
                // Badge đặc trưng - góc trái bên dưới
                if (feature != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _FeatureBadge(text: feature),
                  ),
                // Trái tim - góc phải bên trên
                Positioned(
                  top: 8,
                  right: 8,
                  child: _HeartButton(itemId: item.id),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Thông tin ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 1),
                _StatsLine(item: item),
                const SizedBox(height: 2),
                _PriceLine(price: item.price, oldPrice: oldPriceVal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trái tim like ────────────────────────────────────────────────────────────

class _HeartButton extends ConsumerWidget {
  final String itemId;
  const _HeartButton({required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedMap = ref.watch(likedItemsProvider);
    final likeId = likedMap[itemId];
    final isLiked = likeId != null && likeId.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(context, ref),
      child: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isLiked
            ? const Color(0xFFEF4444)
            : Colors.white.withValues(alpha: 0.90),
        size: 22,
        shadows: const [
          Shadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
    );
  }

  void _toggle(BuildContext context, WidgetRef ref) {
    if (!ref.read(authProvider).isAuthenticated) {
      GoRouter.of(context).push('/login');
      return;
    }
    ref.read(likedItemsProvider.notifier).toggle(itemId);
  }
}

// ── Badge "Đặc trưng:" ────────────────────────────────────────────────────────

class _FeatureBadge extends StatelessWidget {
  final String text;
  const _FeatureBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4B400),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Dòng thống kê (★ rating · đánh giá · km · đã bán) ────────────────────────

class _StatsLine extends StatelessWidget {
  final FoodItemCard item;
  const _StatsLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    if (item.avgRating > 0) {
      final reviewSuffix = item.totalReviews > 0 ? ' (${_fmtNum(item.totalReviews)})' : '';
      parts.add('★ ${_fmtRating(item.avgRating)}$reviewSuffix');
    }
    if (item.distanceKm != null && item.distanceKm! > 0) {
      parts.add(_fmtDistance(item.distanceKm!));
    }
    if (item.soldCount > 0) {
      parts.add('${_fmtSold(item.soldCount)} đã bán');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10,
        color: Colors.black54,
        height: 1.2,
      ),
    );
  }

  // "5.0" → "5", "4.5" → "4.5"
  String _fmtRating(double r) {
    final s = r.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  // < 1km → "300m"; >= 1km → "1.5km" hoặc "2km" (bỏ ".0" thừa)
  String _fmtDistance(double km) {
    if (km < 1.0) return '${(km * 1000).round()}m';
    final s = km.toStringAsFixed(1);
    return s.endsWith('.0') ? '${s.substring(0, s.length - 2)}km' : '${s}km';
  }

  String _fmtNum(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$n';
  }

  String _fmtSold(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.truncateToDouble()
          ? '${k.toInt()}k+'
          : '${k.toStringAsFixed(1)}k+';
    }
    return '$n+';
  }
}

// ── Dòng giá (giá hiện tại + giá cũ gạch ngang nếu có) ──────────────────────

class _PriceLine extends StatelessWidget {
  final int price;
  final int? oldPrice;
  const _PriceLine({required this.price, this.oldPrice});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _vnd(price),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        if (oldPrice != null && oldPrice! > price) ...[
          const SizedBox(width: 6),
          Text(
            _vnd(oldPrice!),
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black38,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.black38,
            ),
          ),
        ],
      ],
    );
  }

  String _vnd(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    buf.write('đ');
    return buf.toString();
  }
}

// ── Hình ảnh món ăn ──────────────────────────────────────────────────────────

class _ItemImage extends StatelessWidget {
  final String? url;
  const _ItemImage({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFFFF3E0),
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: const Color(0xFFF4B400).withValues(alpha: 0.4),
          size: 36,
        ),
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    final transformed = cloudinarySquare(url);

    return CachedNetworkImage(
      imageUrl: transformed,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => _Shimmer(),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}

class _Shimmer extends StatefulWidget {
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + 2 * _ctrl.value, 0),
            end: Alignment(2 * _ctrl.value, 0),
            colors: const [
              Color(0xFFEEEEEE),
              Color(0xFFFAFAFA),
              Color(0xFFEEEEEE),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }
}
