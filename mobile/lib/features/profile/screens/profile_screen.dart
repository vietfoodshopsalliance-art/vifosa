// lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/address_model.dart';

// ── Brand colours (same palette as home screen) ───────────────────────────────
const _bg       = Color(0xFFF7F2E8);
const _card     = Colors.white;
const _accent   = Color(0xFFF4B400);
const _txtMain  = Color(0xFF1A1200);
const _txtSub   = Color(0xFF8A7862);
const _iconBg   = Color(0xFFF2EDE0);
const _divider  = Color(0xFFF0E8D8);

// ── Providers ─────────────────────────────────────────────────────────────────

final _myRatingProvider = FutureProvider.autoDispose<_RatingSummary?>((ref) async {
  try {
    final res = await DioClient.instance.get('/me/reviews');
    final data = res.data as Map<String, dynamic>? ?? {};
    final total = (data['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return null;
    final list = (data['reviews'] as List? ?? []).cast<Map<String, dynamic>>();
    if (list.isEmpty) return null;
    final sum = list.fold<double>(
        0, (s, r) => s + ((r['stars'] as num?)?.toDouble() ?? 0));
    return _RatingSummary(avg: sum / list.length, count: total);
  } catch (_) {
    return null;
  }
});

final _defaultAddressProvider = FutureProvider<AddressModel?>((ref) async {
  ref.watch(authProvider.select((s) => s.user?['_id']));
  try {
    final res = await DioClient.instance.get('/me/addresses');
    final raw = res.data;
    final list = (raw is List
            ? raw
            : (raw as Map<String, dynamic>)['addresses'] as List? ?? [])
        .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list.isEmpty) return null;
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  } catch (_) {
    return null;
  }
});

class _RatingSummary {
  final double avg;
  final int count;
  const _RatingSummary({required this.avg, required this.count});
}

class _OrderStats {
  final int completed;
  final int total;
  const _OrderStats({required this.completed, required this.total});
}

final _myOrderStatsProvider = FutureProvider.autoDispose<_OrderStats>((ref) async {
  try {
    final res = await DioClient.instance.get('/me/order-stats');
    final data = res.data as Map<String, dynamic>? ?? {};
    return _OrderStats(
      completed: (data['completedCount'] as num?)?.toInt() ?? 0,
      total: (data['totalOrders'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return const _OrderStats(completed: 0, total: 0);
  }
});

final _myReviewCountProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final res = await DioClient.instance
        .get('/me/reviews-given', queryParameters: {'limit': 1, 'page': 1});
    final data = res.data as Map<String, dynamic>? ?? {};
    return (data['total'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState  = ref.watch(authProvider);
    final user       = authState.user ?? {};
    final roles      = (user['roles'] as List<dynamic>? ?? []).cast<String>();
    final ownedStores = (user['ownedStores'] as List<dynamic>? ?? []);
    final isStoreOwner = roles.contains('store_owner') || ownedStores.isNotEmpty;
    final avatarUrl  = user['avatarImage'] as String? ?? user['avatar'] as String?;
    final nickname   = user['nickname'] as String? ?? '';
    final username   = user['username'] as String? ?? '';
    final ratingAsync      = ref.watch(_myRatingProvider);
    final orderStatsAsync  = ref.watch(_myOrderStatsProvider);
    final reviewCountAsync = ref.watch(_myReviewCountProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        title: const Text(
          'Hồ sơ',
          style: TextStyle(
            color: _txtMain,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _txtMain),
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _accent,
        onRefresh: () async {
          ref.invalidate(_myRatingProvider);
          ref.invalidate(_defaultAddressProvider);
          ref.invalidate(_myOrderStatsProvider);
          ref.invalidate(_myReviewCountProvider);
          await Future.wait([
            ref.read(_myRatingProvider.future),
            ref.read(_defaultAddressProvider.future),
            ref.read(_myOrderStatsProvider.future),
            ref.read(_myReviewCountProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            // ── Profile header card ──────────────────────────────────────────
            _ProfileHeaderCard(
              avatarUrl: avatarUrl,
              nickname: nickname,
              username: username,
              roles: roles,
              ratingAsync: ratingAsync,
              orderStatsAsync: orderStatsAsync,
              reviewCountAsync: reviewCountAsync,
              onTapRating: () => context.push('/profile/my-rating'),
            ),

            // ── Tài khoản ────────────────────────────────────────────────────
            const _SectionLabel('Tài khoản'),
            _MenuCard(children: [
              const _AddressTile(),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.payment_outlined,
                label: 'Phương thức thanh toán',
                subtitle: 'Cài đặt mặc định & TK nhận hoàn',
                onTap: () => context.push('/profile/payment-methods'),
              ),
            ]),

            // ── Yêu thích & Đánh giá ─────────────────────────────────────────
            const _SectionLabel('Yêu thích & Đánh giá'),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.favorite_outline,
                label: 'Yêu thích',
                subtitle: 'Món và quán yêu thích của tôi',
                onTap: () => context.push('/favorites'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.rate_review_outlined,
                label: 'Quán đã đánh giá',
                subtitle: 'Xem lại các review tôi đã viết',
                onTap: () => context.push('/profile/my-reviews'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.explore_outlined,
                label: 'Khám phá',
                subtitle: 'Bảng xếp hạng & thống kê cộng đồng',
                onTap: () => _showExploreSheet(context),
              ),
            ]),

            // ── Quán của tôi (store owner only) ─────────────────────────────
            if (isStoreOwner) ...[
              const _SectionLabel('Quán của tôi'),
              _MenuCard(children: [
                _MenuTile(
                  icon: Icons.store_outlined,
                  label: 'Quản lý quán',
                  subtitle: 'Dashboard đơn hàng, menu, cài đặt',
                  onTap: () => context.push('/my-stores'),
                ),
              ]),
            ],

            // ── Hỗ trợ ───────────────────────────────────────────────────────
            const _SectionLabel('Hỗ trợ'),
            _MenuCard(children: [
              _MenuTile(
                icon: Icons.volunteer_activism_outlined,
                label: 'Hỗ trợ chúng tôi',
                subtitle: 'Duy trì phần mềm miễn phí, chiết khấu quán 0%',
                onTap: () => context.push('/profile/support-us'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.bug_report_outlined,
                label: 'Báo lỗi / Đề xuất',
                subtitle: 'Gửi phản hồi cho team Viet Shops',
                onTap: () => context.push('/profile/support'),
              ),
              const _MenuDivider(),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Cài đặt',
                subtitle: 'Mật khẩu, thông báo, tài khoản',
                onTap: () => context.push('/profile/settings'),
              ),
            ]),

            const SizedBox(height: 8),

            // ── Đăng xuất ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _LogoutCard(onTap: () => _confirmLogout(context, ref)),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showExploreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExploreSheet(parentContext: context),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Profile Header Card ───────────────────────────────────────────────────────

class _ProfileHeaderCard extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final String username;
  final List<String> roles;
  final AsyncValue<_RatingSummary?> ratingAsync;
  final AsyncValue<_OrderStats> orderStatsAsync;
  final AsyncValue<int> reviewCountAsync;
  final VoidCallback onTapRating;

  const _ProfileHeaderCard({
    required this.avatarUrl,
    required this.nickname,
    required this.username,
    required this.roles,
    required this.ratingAsync,
    required this.orderStatsAsync,
    required this.reviewCountAsync,
    required this.onTapRating,
  });

  @override
  Widget build(BuildContext context) {
    final displayName  = nickname.isNotEmpty ? nickname : username;
    final initial      = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    final visibleRoles = roles.where((r) => r == 'admin' || r == 'mod').toList();

    final summary     = ratingAsync.maybeWhen(data: (d) => d, orElse: () => null);
    final stats       = orderStatsAsync.maybeWhen(data: (d) => d, orElse: () => null);
    final reviewCount = reviewCountAsync.maybeWhen(data: (d) => d, orElse: () => null);

    final ordPct = (stats != null && stats.total > 0)
        ? (stats.completed / stats.total * 100).round()
        : null;
    final revPct = (stats != null && stats.completed > 0 && reviewCount != null)
        ? (reviewCount / stats.completed * 100).round()
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar với viền vàng
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFF4B400), Color(0xFFFF9000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor: _iconBg,
              child: avatarUrl == null
                  ? Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _txtMain,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _txtMain,
                  ),
                ),
                const SizedBox(height: 4),

                // ── Stats row ─────────────────────────────────────────────
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 2,
                  children: [
                    Text(
                      '@$username',
                      style: const TextStyle(color: _txtSub, fontSize: 12.5),
                    ),
                    // ★ điểm bởi chủ quán (số lần)
                    if (summary != null)
                      GestureDetector(
                        onTap: onTapRating,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(' · ', style: TextStyle(color: _txtSub, fontSize: 12)),
                            const Icon(Icons.star_rounded, size: 12, color: _accent),
                            const SizedBox(width: 2),
                            Text(
                              summary.avg.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _txtMain,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '(${summary.count})',
                              style: const TextStyle(fontSize: 11, color: _txtSub),
                            ),
                          ],
                        ),
                      ),
                    // đơn hoàn thành (%)
                    if (ordPct != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(' · ', style: TextStyle(color: _txtSub, fontSize: 12)),
                          const Icon(Icons.shopping_bag_outlined, size: 12, color: _txtSub),
                          const SizedBox(width: 2),
                          Text(
                            '${stats!.completed} ($ordPct%)',
                            style: const TextStyle(fontSize: 12, color: _txtSub),
                          ),
                        ],
                      ),
                    // số lần đánh giá (%)
                    if (reviewCount != null && ordPct != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(' · ', style: TextStyle(color: _txtSub, fontSize: 12)),
                          const Icon(Icons.rate_review_outlined, size: 12, color: _txtSub),
                          const SizedBox(width: 2),
                          Text(
                            revPct != null
                                ? '$reviewCount ($revPct%)'
                                : '$reviewCount',
                            style: const TextStyle(fontSize: 12, color: _txtSub),
                          ),
                        ],
                      ),
                  ],
                ),

                if (visibleRoles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: visibleRoles
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _roleColor(r).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _roleColor(r).withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                _roleLabel(r),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _roleColor(r),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _roleColor(String role) => switch (role) {
        'admin' => Colors.red,
        'mod'   => Colors.purple,
        _       => Colors.blue,
      };

  static String _roleLabel(String role) => switch (role) {
        'admin' => 'Admin',
        'mod'   => 'Mod',
        _       => role,
      };
}

// ── Address Tile ──────────────────────────────────────────────────────────────

class _AddressTile extends ConsumerWidget {
  const _AddressTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addrAsync = ref.watch(_defaultAddressProvider);

    final subtitle = addrAsync.when(
      loading: () => 'Đang tải...',
      error: (_, __) => 'Quản lý địa chỉ giao hàng',
      data: (addr) {
        if (addr == null) return 'Chưa có địa chỉ nào';
        final parts = <String>[];
        if (addr.label.isNotEmpty) parts.add(addr.label);
        if (addr.text.isNotEmpty) parts.add(addr.text);
        return parts.isNotEmpty ? parts.join(': ') : 'Địa chỉ mặc định';
      },
    );

    return _MenuTile(
      icon: Icons.location_on_outlined,
      label: 'Địa chỉ của tôi',
      subtitle: subtitle,
      onTap: () => GoRouter.of(context).push('/profile/addresses'),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFA07830),
            letterSpacing: 1.0,
          ),
        ),
      );
}

// ── Menu Card (white rounded card grouping items) ─────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: children),
        ),
      );
}

// ── Menu Divider ──────────────────────────────────────────────────────────────

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 60,
        color: _divider,
      );
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF6B5230)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _txtMain,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: const TextStyle(fontSize: 12, color: _txtSub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFFBDB6A8), size: 20),
            ],
          ),
        ),
      );
}

// ── Logout Card ───────────────────────────────────────────────────────────────

class _LogoutCard extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutCard({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Đăng xuất',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Explore Sheet ─────────────────────────────────────────────────────────────

class _ExploreSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _ExploreSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Khám phá',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _ExploreItem(
            icon: Icons.fastfood_outlined,
            label: 'Món bán chạy nhất',
            parentContext: parentContext,
          ),
          _ExploreItem(
            icon: Icons.storefront_outlined,
            label: 'Quán được đánh giá nhiều nhất',
            parentContext: parentContext,
          ),
          _ExploreItem(
            icon: Icons.workspace_premium_outlined,
            label: 'Người dùng được quán chấm điểm nhiều nhất',
            parentContext: parentContext,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ExploreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final BuildContext parentContext;

  const _ExploreItem({
    required this.icon,
    required this.label,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Text(
          'Đang build',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Text('Tính năng đang xây dựng, sắp ra mắt!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

// ── My Rating Screen ──────────────────────────────────────────────────────────

class MyRatingScreen extends ConsumerWidget {
  const MyRatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myRatingDetailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Điểm đánh giá của tôi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có quán nào đánh giá bạn',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final avg = data
                  .map((r) => r['stars'] as int)
                  .reduce((a, b) => a + b) /
              data.length;

          return Column(
            children: [
              Container(
                color: Colors.amber.shade50,
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 22,
                            ),
                          ),
                        ),
                        Text(
                          '${data.length} lượt đánh giá',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RatingTile(review: data[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final _myRatingDetailProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.get('/me/reviews');
  final list = res.data['reviews'] as List? ?? [];
  return list.cast<Map<String, dynamic>>();
});

class _RatingTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _RatingTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final store     = review['fromUserId'] as Map<String, dynamic>?;
    final storeName = store?['nickname'] as String? ?? 'Quán';
    final stars     = (review['stars'] as num?)?.toInt() ?? 0;
    final comment   = review['comment'] as String? ?? '';
    final dt =
        DateTime.tryParse(review['createdAt'] as String? ?? '') ?? DateTime.now();

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (store?['avatar'] as String?) != null
            ? NetworkImage(store!['avatar'] as String)
            : null,
        child: (store?['avatar'] as String?) == null
            ? Text(storeName.isNotEmpty ? storeName[0] : 'Q')
            : null,
      ),
      title: Row(
        children: [
          Text(storeName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          ...List.generate(
            5,
            (i) => Icon(
              i < stars ? Icons.star : Icons.star_border,
              size: 14,
              color: Colors.amber,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.isNotEmpty)
            Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(
            '${dt.day}/${dt.month}/${dt.year}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      isThreeLine: comment.isNotEmpty,
    );
  }
}
