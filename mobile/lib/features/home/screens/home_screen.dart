// lib/features/home/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_provider.dart';
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
                if (isAuth) _AvatarMenuButton(user: user),
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

            // ── Grid món ăn gần bạn ─────────────────────────────────────────
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

    if (state.items.isEmpty) {
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
                  'Món ăn gần bạn',
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
              (_, i) {
                final item = state.items[i];
                return FoodItemCardWidget(
                  item: item,
                  onTap: () => context.push('/store/${item.storeId}'),
                );
              },
              childCount: state.items.length,
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
}

// ── Avatar menu button ────────────────────────────────────────────────────────

class _AvatarMenuButton extends ConsumerWidget {
  final Map<String, dynamic>? user;
  const _AvatarMenuButton({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = user?['nickname'] as String? ??
        user?['username'] as String? ??
        '';
    final avatarUrl =
        user?['avatarImage'] as String? ?? user?['avatar'] as String?;

    return PopupMenuButton<_MenuOption>(
      offset: const Offset(0, 50),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (option) => _onSelected(context, ref, option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _buildAvatar(avatarUrl, nickname),
      ),
      itemBuilder: (_) => [
        _menuItem(_MenuOption.profile, Icons.person_outline, 'Profile'),
        _menuItem(
            _MenuOption.storeDashboard, Icons.storefront_outlined, 'Quản lý quán'),
        const PopupMenuDivider(),
        _menuItem(_MenuOption.logout, Icons.logout_rounded, 'Thoát',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<_MenuOption> _menuItem(
    _MenuOption option,
    IconData icon,
    String label, {
    bool destructive = false,
  }) {
    final color =
        destructive ? const Color(0xFFEF4444) : const Color(0xFF374151);
    return PopupMenuItem(
      value: option,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 14, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String nickname) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFF4B400),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(radius: 15, backgroundImage: NetworkImage(url));
    }
    final color =
        colors[(nickname.isNotEmpty ? nickname.codeUnitAt(0) : 0) % colors.length];
    return CircleAvatar(
      radius: 15,
      backgroundColor: color,
      child: Text(
        nickname.isNotEmpty ? nickname[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _onSelected(BuildContext context, WidgetRef ref, _MenuOption option) {
    switch (option) {
      case _MenuOption.profile:
        context.push('/profile');
      case _MenuOption.storeDashboard:
        context.push('/my-stores');
      case _MenuOption.logout:
        ref.read(authProvider.notifier).logout();
    }
  }
}

enum _MenuOption { profile, storeDashboard, logout }
