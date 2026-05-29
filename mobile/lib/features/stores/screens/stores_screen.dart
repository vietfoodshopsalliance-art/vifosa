// lib/features/stores/screens/stores_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/liked_stores_provider.dart';
import '../../../core/utils/cloudinary_utils.dart';
import '../../../core/widgets/avatar_menu_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/models/store_card.dart';
import '../../home/providers/home_feed_provider.dart';

const _kRadius = 25;

class StoresScreen extends ConsumerStatefulWidget {
  const StoresScreen({super.key});

  @override
  ConsumerState<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends ConsumerState<StoresScreen> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(nearbyStoresProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(nearbyStoresProvider.notifier).refresh();
    ref.read(likedStoresProvider.notifier).reload();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuth = authState.isAuthenticated;
    final user = authState.user;
    final nearbyState = ref.watch(nearbyStoresProvider);
    final feedAsync = ref.watch(homeFeedDataProvider(_kRadius));

    // Gom tất cả nhóm (new, trending, recent, favorites, nearby), dedup theo ID
    final feedData = feedAsync.valueOrNull;
    final seenIds = <String>{};
    final allStores = [
      ...(feedData?.newStores ?? []).take(2),
      ...(feedData?.trendingStores ?? []),
      ...(feedData?.recentPurchases ?? []),
      ...(feedData?.favorites ?? []),
      ...nearbyState.stores,
    ].where((s) {
      if (seenIds.contains(s.id)) return false;
      seenIds.add(s.id);
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E8),
      body: RefreshIndicator(
        color: const Color(0xFFF4B400),
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black12,
              forceElevated: true,
              titleSpacing: 14,
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/vietshop_logo_ngang.png',
                    height: 14,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/search'),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: Colors.black38, size: 18),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Tìm quán, món ăn...',
                                style: TextStyle(
                                    color: Colors.black38, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (isAuth)
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined,
                        color: Colors.black87),
                    tooltip: 'Thông báo',
                    onPressed: () => context.push('/notifications'),
                  ),
                if (isAuth) AvatarMenuButton(user: user),
                if (!isAuth)
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        color: Color(0xFFF4B400),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),

            // ── Content ──────────────────────────────────────────────────────
            if (nearbyState.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF4B400)),
                ),
              )
            else if (nearbyState.error != null && allStores.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_outlined,
                          size: 56, color: Colors.black26),
                      const SizedBox(height: 12),
                      const Text('Không tải được dữ liệu.',
                          style: TextStyle(color: Colors.black45)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF4B400),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _onRefresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (allStores.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.store_mall_directory_outlined,
                          size: 64, color: Colors.black26),
                      SizedBox(height: 12),
                      Text('Chưa có quán nào trong khu vực.',
                          style: TextStyle(color: Colors.black45),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
            else
              SliverMainAxisGroup(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.76,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final store = allStores[i];
                          return StoreGridCard(
                            store: store,
                            onTap: () => context.push('/store/${store.id}'),
                          );
                        },
                        childCount: allStores.length,
                      ),
                    ),
                  ),

                  if (nearbyState.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF4B400),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Card quán 2-cột ───────────────────────────────────────────────────────────

class StoreGridCard extends ConsumerWidget {
  final StoreCard store;
  final VoidCallback? onTap;

  const StoreGridCard({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuth = ref.watch(authProvider.select((s) => s.isAuthenticated));
    final likedMap = ref.watch(likedStoresProvider);
    final likeId = likedMap[store.id];
    final isLiked = likeId != null && likeId != '__pending__';
    final feature = _parseFeature(store.description);

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
            // Hình quán
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 3,
                              offset: const Offset(0, 7),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _StoreImage(
                            url: store.coverImage ?? store.avatarImage,
                          ),
                        ),
                      ),
                    ),

                    // Trạng thái mở/đóng — góc trên bên TRÁI
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _OpenBadge(open: store.effectivelyOpen),
                    ),

                    // Nút like — góc trên bên PHẢI
                    if (isAuth)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _LikeButton(
                          storeId: store.id,
                          isLiked: isLiked,
                        ),
                      ),

                    // Badge đặc trưng — góc dưới bên trái
                    if (feature != null)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: _Badge(text: feature),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _StoreStats(store: store),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _parseFeature(String? desc) {
    if (desc == null || desc.isEmpty) return null;
    for (final line in desc.split('\n')) {
      final l = line.trim();
      if (l.startsWith('Đặc trưng:')) {
        final val = l.substring('Đặc trưng:'.length).trim();
        return val.isEmpty ? null : val;
      }
    }
    return null;
  }
}

// ── Like button ────────────────────────────────────────────────────────────────

class _LikeButton extends ConsumerWidget {
  final String storeId;
  final bool isLiked;
  const _LikeButton({required this.storeId, required this.isLiked});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(likedStoresProvider.notifier).toggle(storeId),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isLiked ? const Color(0xFFEF4444) : Colors.white,
          size: 15,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }
}

// ── Stats line ─────────────────────────────────────────────────────────────────

class _StoreStats extends StatelessWidget {
  final StoreCard store;
  const _StoreStats({required this.store});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    if (store.avgRating > 0) {
      final rating = _fmtRating(store.avgRating);
      final reviews =
          store.totalReviews > 0 ? ' (${_fmtNum(store.totalReviews)})' : '';
      parts.add('★ $rating$reviews');
    }
    if (store.distanceKm != null) {
      parts.add(_fmtDistance(store.distanceKm!));
    }
    if (store.totalSold > 0) {
      parts.add('${_fmtSold(store.totalSold)} đã bán');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10, color: Colors.black54),
    );
  }

  String _fmtRating(double r) {
    final s = r.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

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

// ── Badge đặc trưng ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4B400),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ── Badge mở/đóng ─────────────────────────────────────────────────────────────

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open
        ? const Color(0xFF22C55E).withValues(alpha: 0.92)
        : Colors.grey.withValues(alpha: 0.75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            open ? 'Mở' : 'Đóng',
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Hình quán ─────────────────────────────────────────────────────────────────

class _StoreImage extends StatelessWidget {
  final String? url;
  const _StoreImage({this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFFFF3E0),
      child: Center(
        child: Icon(
          Icons.storefront_outlined,
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
      placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
