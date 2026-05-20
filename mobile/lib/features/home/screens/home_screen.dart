// lib/features/home/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/providers/auth_provider.dart';
import '../models/store_card.dart';
import '../providers/home_feed_provider.dart';
import '../widgets/store_card_widget.dart';

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

  void _onScroll() {
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      ref.read(nearbyStoresProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = ref.watch(selectedRadiusProvider);
    final isAuth = ref.watch(authProvider).isAuthenticated;
    final user = ref.watch(authProvider).user;
    final roles = (user?['roles'] as List<dynamic>?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: RefreshIndicator(
        color: const Color(0xFFE53935),
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            // ── AppBar ────────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white,
              elevation: 1,
              titleSpacing: 16,
              title: const Row(
                children: [
                  Icon(Icons.restaurant_menu,
                      color: Color(0xFFE53935), size: 22),
                  const SizedBox(width: 6),
                  const Text(
                    'Vifosa',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.black87),
                  tooltip: 'Tìm kiếm',
                  onPressed: () => context.go('/search'),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.black87),
                  tooltip: 'Thông báo',
                  onPressed: () => context.push('/notifications'),
                ),
                if (roles.length > 1) _RoleMenuButton(user: user, roles: roles),
                const SizedBox(width: 4),
              ],
            ),

            // ── Radius selector ───────────────────────────────────────
            SliverToBoxAdapter(child: _RadiusSelector(radius: radius)),

            // ── Section 1: Quán mới ───────────────────────────────────
            _SectionSliver(
              title: 'Quán mới',
              provider: newStoresProvider(radius),
            ),

            // ── Section 3: Bán chạy ───────────────────────────────────
            _SectionSliver(
              title: 'Bán chạy 30 ngày',
              provider: popularStoresProvider(radius),
            ),

            // ── Section 4: Đã mua gần đây (logged-in) ────────────────
            if (isAuth)
              _SectionSliver(
                title: 'Đã mua gần đây',
                provider: recentPurchaseStoresProvider,
              ),

            // ── Section 5: Yêu thích (logged-in) ─────────────────────
            if (isAuth)
              _SectionSliver(
                title: 'Yêu thích',
                provider: favoriteStoresProvider,
              ),

            // ── Section 6: Quán gần bạn (infinite scroll) ────────────
            _NearbySection(),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    final radius = ref.read(selectedRadiusProvider);
    ref.invalidate(homeFeedDataProvider(radius));
    await ref.read(nearbyStoresProvider.notifier).refresh();
  }
}

// ── Radius selector ───────────────────────────────────────────────────────────

class _RadiusSelector extends ConsumerWidget {
  final int radius;
  const _RadiusSelector({required this.radius});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16, color: Color(0xFF888888)),
          const SizedBox(width: 4),
          const Text('Bán kính:',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          const SizedBox(width: 8),
          ...[5, 10, 25].map(
            (r) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${r}km'),
                selected: radius == r,
                onSelected: (_) =>
                    ref.read(selectedRadiusProvider.notifier).state = r,
                selectedColor: const Color(0xFFE53935),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: radius == r ? Colors.white : const Color(0xFF555555),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: radius == r
                        ? const Color(0xFFE53935)
                        : const Color(0xFFDDDDDD),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic horizontal section (dùng FutureProvider) ─────────────────────────

class _SectionSliver extends ConsumerWidget {
  final String title;
  final ProviderListenable<AsyncValue<List<StoreCard>>> provider;

  const _SectionSliver({required this.title, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);

    return async.when(
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (stores) {
        if (stores.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 196,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.only(left: 16, right: 4, bottom: 4),
                  itemCount: stores.length,
                  itemBuilder: (_, i) => StoreCardHorizontal(
                    store: stores[i],
                    onTap: () => context.push('/store/${stores[i].id}'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Section 6: Nearby stores (infinite scroll) ───────────────────────────────

class _NearbySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nearbyStoresProvider);

    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFE53935)),
        ),
      );
    }

    if (state.error != null && state.stores.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined,
                  size: 56, color: Colors.black26),
              const SizedBox(height: 12),
              const Text('Không tải được dữ liệu.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.read(nearbyStoresProvider.notifier).refresh(),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.stores.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_mall_directory_outlined,
                  size: 64, color: Colors.black26),
              SizedBox(height: 12),
              Text('Không có quán nào trong khu vực này.',
                  style: TextStyle(color: Colors.black45)),
              SizedBox(height: 4),
              Text('Thử mở rộng bán kính tìm kiếm.',
                  style: TextStyle(fontSize: 12, color: Colors.black38)),
            ],
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text(
              'Quán gần bạn',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => StoreCardVertical(
              store: state.stores[i],
              onTap: () => context.push('/store/${state.stores[i].id}'),
            ),
            childCount: state.stores.length,
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
                    color: Color(0xFFE53935),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Role menu button (AppBar) ─────────────────────────────────────────────────

class _RoleMenuButton extends ConsumerWidget {
  final Map<String, dynamic>? user;
  final List<String> roles;
  const _RoleMenuButton({required this.user, required this.roles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = user?['nickname'] as String? ??
        user?['username'] as String? ??
        '';
    final avatarUrl = user?['avatarImage'] as String?;

    return PopupMenuButton<_RoleOption>(
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (option) => _onSelected(context, ref, option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(avatarUrl, nickname),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: Colors.black54),
          ],
        ),
      ),
      itemBuilder: (_) => [
        _menuItem(_RoleOption.home, Icons.home_outlined, 'Trang chủ khách hàng'),
        if (roles.contains('store_owner'))
          _menuItem(_RoleOption.storeDashboard, Icons.storefront_outlined,
              'Dashboard quán'),
        if (roles.contains('admin'))
          _menuItem(_RoleOption.admin, Icons.admin_panel_settings_outlined,
              'Quản trị'),
        const PopupMenuDivider(),
        _menuItem(_RoleOption.logout, Icons.logout_rounded, 'Đăng xuất',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<_RoleOption> _menuItem(
    _RoleOption option,
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
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? url, String nickname) {
    const colors = [
      Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B),
      Color(0xFFEF4444), Color(0xFF8B5CF6),
    ];
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
          radius: 15, backgroundImage: NetworkImage(url));
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

  void _onSelected(BuildContext context, WidgetRef ref, _RoleOption option) {
    switch (option) {
      case _RoleOption.home:
        context.go('/home');
      case _RoleOption.storeDashboard:
        context.push('/my-stores');
      case _RoleOption.admin:
        context.push('/admin');
      case _RoleOption.logout:
        ref.read(authProvider.notifier).logout();
    }
  }
}

enum _RoleOption { home, storeDashboard, admin, logout }
