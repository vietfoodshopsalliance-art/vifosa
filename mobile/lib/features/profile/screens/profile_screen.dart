// lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';

// Provider: lấy điểm trung bình được quán đánh giá
final _myRatingProvider = FutureProvider<_RatingSummary?>((ref) async {
  try {
    final res = await DioClient.instance.get('/me/reviews');
    final data = res.data as Map<String, dynamic>? ?? {};
    final total = (data['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return null;
    final avg = (data['avgStars'] as num?)?.toDouble();
    return avg != null ? _RatingSummary(avg: avg, count: total) : null;
  } catch (_) {
    return null;
  }
});

class _RatingSummary {
  final double avg;
  final int count;
  const _RatingSummary({required this.avg, required this.count});
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user ?? {};

    final roles = (user['roles'] as List<dynamic>? ?? []).cast<String>();
    final ownedStores = (user['ownedStores'] as List<dynamic>? ?? []);
    final isStoreOwner = roles.contains('store_owner') || ownedStores.isNotEmpty;
    final avatarUrl = user['avatarImage'] as String? ?? user['avatar'] as String?;
    final nickname = user['nickname'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final ratingAsync = ref.watch(_myRatingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Chỉnh sửa hồ sơ',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // ── Header: avatar + tên + rating ────────────────────────────────
          _ProfileHeader(
            avatarUrl: avatarUrl,
            nickname: nickname,
            username: username,
            roles: roles,
            ratingAsync: ratingAsync,
            onTapRating: () => context.push('/profile/my-rating'),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── Section: Tài khoản & Cá nhân ─────────────────────────────────
          _SectionLabel('Tài khoản'),
          _MenuItem(
            icon: Icons.person_outline,
            label: 'Chỉnh sửa hồ sơ',
            subtitle: 'Tên hiển thị, ảnh đại diện',
            onTap: () => context.push('/profile/edit'),
          ),
          _MenuItem(
            icon: Icons.location_on_outlined,
            label: 'Địa chỉ của tôi',
            subtitle: 'Quản lý địa chỉ giao hàng',
            onTap: () => context.push('/profile/addresses'),
          ),
          _MenuItem(
            icon: Icons.payment_outlined,
            label: 'Phương thức thanh toán',
            subtitle: 'Cài đặt mặc định & TK nhận hoàn',
            onTap: () => context.push('/profile/payment-methods'),
          ),

          const Divider(height: 1),

          // ── Section: Yêu thích & Đánh giá ────────────────────────────────
          _SectionLabel('Yêu thích & Đánh giá'),
          _MenuItem(
            icon: Icons.favorite_outline,
            label: 'Yêu thích',
            subtitle: 'Món và quán yêu thích của tôi',
            onTap: () => context.push('/favorites'),
          ),
          _MenuItem(
            icon: Icons.rate_review_outlined,
            label: 'Quán đã đánh giá',
            subtitle: 'Xem lại các review tôi đã viết',
            onTap: () => context.push('/profile/my-reviews'),
          ),
          if (ratingAsync.hasValue && ratingAsync.value != null)
            _MenuItem(
              icon: Icons.star_outline,
              label: 'Điểm đánh giá của tôi',
              subtitle: '${ratingAsync.value!.avg.toStringAsFixed(1)}★ — ${ratingAsync.value!.count} lượt',
              onTap: () => context.push('/profile/my-rating'),
            ),

          const Divider(height: 1),

          // ── Section: Quán (chỉ hiện với store_owner) ─────────────────────
          if (isStoreOwner) ...[
            _SectionLabel('Quán của tôi'),
            _MenuItem(
              icon: Icons.store_outlined,
              label: 'Quản lý quán',
              subtitle: 'Dashboard đơn hàng, menu, cài đặt',
              onTap: () => context.push('/my-stores'),
            ),
            const Divider(height: 1),
          ],

          // ── Section: Hỗ trợ ───────────────────────────────────────────────
          _SectionLabel('Hỗ trợ'),
          _MenuItem(
            icon: Icons.bug_report_outlined,
            label: 'Báo lỗi / Đề xuất',
            subtitle: 'Gửi phản hồi cho team Vifosa',
            onTap: () => context.push('/profile/support'),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Cài đặt',
            subtitle: 'Mật khẩu, thông báo, tài khoản',
            onTap: () => context.push('/profile/settings'),
          ),

          const Divider(height: 1),
          const SizedBox(height: 8),

          // ── Logout ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _confirmLogout(context, ref),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
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

// ---------------------------------------------------------------------------
// Profile Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final String username;
  final List<String> roles;
  final AsyncValue<_RatingSummary?> ratingAsync;
  final VoidCallback onTapRating;

  const _ProfileHeader({
    required this.avatarUrl,
    required this.nickname,
    required this.username,
    required this.roles,
    required this.ratingAsync,
    required this.onTapRating,
  });

  @override
  Widget build(BuildContext context) {
    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 40,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(initial, style: const TextStyle(fontSize: 28))
                : null,
          ),
          const SizedBox(width: 16),

          // Tên + username + rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname.isNotEmpty ? nickname : username,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '@$username',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 6),
                // Roles badges
                if (roles.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: roles
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _roleColor(r).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _roleColor(r).withOpacity(0.4)),
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

                // Rating
                ratingAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (summary) {
                    if (summary == null) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: onTapRating,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 3),
                            Text(
                              '${summary.avg.toStringAsFixed(1)} (${summary.count})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '· từ quán',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _roleColor(String role) {
    return switch (role) {
      'admin'       => Colors.red,
      'mod'         => Colors.purple,
      'store_owner' => Colors.orange,
      _             => Colors.blue,
    };
  }

  static String _roleLabel(String role) {
    return switch (role) {
      'admin'       => 'Admin',
      'mod'         => 'Mod',
      'store_owner' => 'Chủ quán',
      'customer'    => 'Khách hàng',
      _             => role,
    };
  }
}

// ---------------------------------------------------------------------------
// My Rating Screen (inline — hiển thị reviews nhận từ quán)
// ---------------------------------------------------------------------------

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

          final avg = data.isEmpty
              ? 0.0
              : data.map((r) => r['stars'] as int).reduce((a, b) => a + b) / data.length;

          return Column(
            children: [
              // Summary header
              Container(
                color: Colors.amber.shade50,
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avg.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < avg.round() ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 22,
                            ),
                          ),
                        ),
                        Text(
                          '${data.length} lượt đánh giá',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
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

final _myRatingDetailProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient.instance.get('/me/reviews');
  final list = res.data['reviews'] as List? ?? [];
  return list.cast<Map<String, dynamic>>();
});

class _RatingTile extends StatelessWidget {
  final Map<String, dynamic> review;
  const _RatingTile({required this.review});

  @override
  Widget build(BuildContext context) {
    final store = review['fromUserId'] as Map<String, dynamic>?;
    final storeName = store?['nickname'] as String? ?? 'Quán';
    final stars = (review['stars'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final dt = DateTime.tryParse(review['createdAt'] as String? ?? '') ?? DateTime.now();

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
          Text(storeName, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          ...List.generate(5, (i) => Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.amber,
          )),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comment.isNotEmpty) Text(comment, maxLines: 2, overflow: TextOverflow.ellipsis),
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

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        title: Text(label),
        subtitle: subtitle != null
            ? Text(subtitle!, style: const TextStyle(fontSize: 12))
            : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      );
}
