// lib/features/home/screens/home_screen.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/avatar_menu_button.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/food_item_card.dart';
import '../providers/home_feed_provider.dart';
import '../widgets/food_item_card_widget.dart';

// Provider để scaffold_with_nav trigger scroll-to-top
final homeScrollToTopProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuth = authState.isAuthenticated;
    final user = authState.user;

    // Scroll to top khi dropdown "Trang chủ" được nhấn
    ref.listen(homeScrollToTopProvider, (_, __) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E8),
      body: RefreshIndicator(
        color: const Color(0xFFF4B400),
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── AppBar ──────────────────────────────────────────────────────
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

            // ── Grid món ăn ─────────────────────────────────────────────────
            _FoodItemsSection(scrollCtrl: _scrollCtrl),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    await ref.read(nearbyStoresProvider.notifier).refresh();
  }

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(nearbyStoresProvider.notifier).loadMore();
    }
  }
}

// ── Grid section món ăn ───────────────────────────────────────────────────────

class _FoodItemsSection extends ConsumerWidget {
  final ScrollController scrollCtrl;
  const _FoodItemsSection({required this.scrollCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyStoresProvider);
    final isAuth = ref.watch(authProvider.select((s) => s.isAuthenticated));

    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFF4B400)),
        ),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
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
      );
    }

    // Xây danh sách slot theo thứ tự ưu tiên
    final slots = _buildSlots(state, isAuth);

    if (slots.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant_menu_outlined,
                  size: 64, color: Colors.black26),
              SizedBox(height: 12),
              Text('Chưa có món ăn nào trong khu vực.',
                  style: TextStyle(color: Colors.black45),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B400),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.near_me_rounded,
                    size: 18, color: Color(0xFFF4B400)),
                const SizedBox(width: 6),
                const Text(
                  'Món ngon gần bạn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Grid 2 cột
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildSlotWidget(ctx, slots[i]),
              childCount: slots.length,
            ),
          ),
        ),

        // Loading more indicator
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
      ],
    );
  }

  List<_GridSlot> _buildSlots(NearbyState state, bool isAuth) {
    final slots = <_GridSlot>[];

    // ô 1: món bán chạy nhất của quán mới mở nhất
    if (state.newStoreItems.isNotEmpty) {
      slots.add(_StaticSlot(state.newStoreItems[0]));
    }
    // ô 2: món bán chạy nhất của quán mới mở nhì
    if (state.newStoreItems.length > 1) {
      slots.add(_StaticSlot(state.newStoreItems[1]));
    }
    // ô 3: slideshow top 10 món bán chạy nhất all-time toàn quốc
    if (state.topSellingItems.isNotEmpty) {
      slots.add(_SlideshowSlot(state.topSellingItems, const ValueKey('slot_3')));
    }
    // ô 4: slideshow món bán chạy nhất của top 5 quán nhiều đánh giá nhất (5km)
    if (state.topReviewedStoreItems.isNotEmpty) {
      slots.add(_SlideshowSlot(state.topReviewedStoreItems, const ValueKey('slot_4')));
    }
    // ô 5: slideshow cá nhân (chỉ khi đăng nhập và có data)
    if (isAuth && state.personalItems.isNotEmpty) {
      slots.add(_SlideshowSlot(state.personalItems, const ValueKey('slot_5')));
    }
    // ô 6+: theo khoảng cách, gần đến xa
    for (final item in state.items) {
      slots.add(_StaticSlot(item));
    }

    return slots;
  }

  Widget _buildSlotWidget(BuildContext ctx, _GridSlot slot) {
    if (slot is _SlideshowSlot) {
      return _SlideshowCard(key: slot.key, items: slot.items);
    }
    final item = (slot as _StaticSlot).item;
    return FoodItemCardWidget(
      item: item,
      onTap: () => ctx.push('/store/${item.storeId}'),
    );
  }
}

// ── Grid slot types ───────────────────────────────────────────────────────────

sealed class _GridSlot {}

class _StaticSlot extends _GridSlot {
  final FoodItemCard item;
  _StaticSlot(this.item);
}

class _SlideshowSlot extends _GridSlot {
  final List<FoodItemCard> items;
  final Key key;
  _SlideshowSlot(this.items, this.key);
}

// ── Slideshow card ────────────────────────────────────────────────────────────

class _SlideshowCard extends StatefulWidget {
  final List<FoodItemCard> items;
  const _SlideshowCard({super.key, required this.items});

  @override
  State<_SlideshowCard> createState() => _SlideshowCardState();
}

class _SlideshowCardState extends State<_SlideshowCard> {
  int _idx = 0;
  Timer? _cycleTimer;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) _scheduleCycle();
  }

  void _scheduleCycle() {
    _cycleTimer?.cancel();
    final secs = 5 + Random().nextInt(4); // 5–8 giây
    _cycleTimer = Timer(Duration(seconds: secs), () {
      if (!mounted) return;
      setState(() => _idx = (_idx + 1) % widget.items.length);
      _scheduleCycle();
    });
  }

  void _pause() {
    _cycleTimer?.cancel();
    _resumeTimer?.cancel();
  }

  void _scheduleResume() {
    _resumeTimer?.cancel();
    if (widget.items.length <= 1) return;
    _resumeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _scheduleCycle();
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final item = widget.items[_idx];
    return Listener(
      onPointerDown: (_) => _pause(),
      onPointerUp: (_) => _scheduleResume(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: FoodItemCardWidget(
          key: ValueKey(_idx),
          item: item,
          onTap: () => context.push('/store/${item.storeId}'),
        ),
      ),
    );
  }
}

