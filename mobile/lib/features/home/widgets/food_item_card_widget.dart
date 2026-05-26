// lib/features/home/widgets/food_item_card_widget.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/services/image_service.dart';
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
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hình món ăn floating 3D ──────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Stack(
                  children: [
                    // Ảnh với bóng đổ vàng
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.38),
                              blurRadius: 18,
                              spreadRadius: 3,
                              offset: const Offset(0, 7),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.13),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _ItemImage(url: item.image),
                        ),
                      ),
                    ),
                    // Badge đặc trưng (chỉ hiển thị nếu có)
                    if (feature != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _FeatureBadge(text: feature),
                      ),
                  ],
                ),
              ),
            ),

            // ── Thông tin bên dưới ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tên món
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
                  const SizedBox(height: 3),
                  // 4 chỉ số trên 1 dòng
                  _StatsLine(item: item),
                  const SizedBox(height: 4),
                  // Giá tiền
                  _PriceLine(price: item.price, oldPrice: oldPriceVal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      parts.add('★ ${item.avgRating.toStringAsFixed(1)}');
    }
    if (item.totalReviews > 0) {
      parts.add('${_fmtNum(item.totalReviews)} đg');
    }
    if (item.distanceKm != null) {
      parts.add('${item.distanceKm!.toStringAsFixed(1)}km');
    }
    if (item.soldCount > 0) {
      parts.add('${_fmtSold(item.soldCount)} đã bán');
    }

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
            color: Color(0xFFD32F2F),
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

    final transformed = ImageService.thumbnail(url!, size: 400);

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
