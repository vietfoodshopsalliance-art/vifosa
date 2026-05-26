// lib/features/stores/screens/stores_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/image_service.dart';
import '../../home/models/store_card.dart';
import '../../home/providers/home_feed_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyStoresProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E8),
      body: RefreshIndicator(
        color: const Color(0xFFF4B400),
        onRefresh: () => ref.read(nearbyStoresProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────────
            const SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              forceElevated: true,
              titleSpacing: 16,
              title: Text(
                'Quán gần bạn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFF4B400)),
                ),
              )
            else if (state.error != null && state.stores.isEmpty)
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
                        onPressed: () =>
                            ref.read(nearbyStoresProvider.notifier).refresh(),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            else if (state.stores.isEmpty)
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

                  // Grid 2 cột
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final store = state.stores[i];
                          return StoreGridCard(
                            store: store,
                            onTap: () => context.push('/store/${store.id}'),
                          );
                        },
                        childCount: state.stores.length,
                      ),
                    ),
                  ),

                  if (state.isLoadingMore)
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

class StoreGridCard extends StatelessWidget {
  final StoreCard store;
  final VoidCallback? onTap;

  const StoreGridCard({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
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
            // Hình quán với floating 3D
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
                    // Badge đặc trưng nếu có
                    if (feature != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Badge(text: feature),
                      ),
                    // Trạng thái mở/đóng
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _OpenBadge(open: store.effectivelyOpen),
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

class _StoreStats extends StatelessWidget {
  final StoreCard store;
  const _StoreStats({required this.store});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (store.avgRating > 0) {
      parts.add('★ ${store.avgRating.toStringAsFixed(1)}');
    }
    if (store.totalReviews > 0) {
      parts.add('${_fmtNum(store.totalReviews)} đg');
    }
    if (store.distanceKm != null) {
      parts.add('${store.distanceKm!.toStringAsFixed(1)}km');
    }

    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 10, color: Colors.black54),
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
}

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

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: open
            ? const Color(0xFFF4B400).withValues(alpha: 0.9)
            : Colors.black.withValues(alpha: 0.55),
      ),
      child: Text(
        open ? 'Mở' : 'Đóng',
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

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
    final transformed = ImageService.thumbnail(url!, size: 400);

    return CachedNetworkImage(
      imageUrl: transformed,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: const Color(0xFFEEEEEE)),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
