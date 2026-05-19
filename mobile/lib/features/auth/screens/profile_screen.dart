// lib/features/auth/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ của tôi')),
      body: ListView(
        children: [
          // Avatar + info header
          Container(
            color: theme.colorScheme.primary.withOpacity(0.05),
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                UserAvatar(
                  imageUrl: auth.avatar,
                  nickname: auth.nickname ?? 'U',
                  size: 64,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.nickname ?? 'Người dùng',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.roles.map(_roleLabel).join(' · '),
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditNickname(context, ref, auth.nickname ?? ''),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            title: 'Địa chỉ đã lưu',
            onTap: () => context.push('/profile/addresses'),
          ),
          _ProfileTile(
            icon: Icons.receipt_long_outlined,
            title: 'Đơn hàng của tôi',
            onTap: () => context.push('/orders'),
          ),
          _ProfileTile(
            icon: Icons.favorite_border,
            title: 'Cửa hàng yêu thích',
            onTap: () => context.push('/favorites'),
          ),
          _ProfileTile(
            icon: Icons.article_outlined,
            title: 'Bài viết của tôi',
            onTap: () => context.push('/social/feed'),
          ),
          const Divider(height: 24),
          _ProfileTile(
            icon: Icons.settings_outlined,
            title: 'Cài đặt tài khoản',
            onTap: () => context.push('/profile/settings'),
          ),
          _ProfileTile(
            icon: Icons.support_agent_outlined,
            title: 'Hỗ trợ',
            onTap: () => context.push('/support'),
          ),
          _ProfileTile(
            icon: Icons.description_outlined,
            title: 'Điều khoản sử dụng',
            onTap: () => context.push('/tos'),
          ),
          const Divider(height: 24),
          if (auth.isStoreOwner)
            _ProfileTile(
              icon: Icons.storefront_outlined,
              title: 'Quản lý cửa hàng',
              onTap: () {
                ref.read(authProvider.notifier).switchRole('store_owner');
                context.go('/store-dashboard');
              },
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Chủ cửa hàng', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          _ProfileTile(
            icon: Icons.logout,
            title: 'Đăng xuất',
            titleColor: Colors.red,
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'customer': return 'Khách hàng';
      case 'store_owner': return 'Chủ cửa hàng';
      case 'admin': return 'Quản trị';
      default: return role;
    }
  }

  void _showEditNickname(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đổi tên hiển thị'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Tên hiển thị', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                await DioClient().dio.patch(ApiEndpoints.me, data: {'nickname': ctrl.text.trim()});
                await ref.read(authProvider.notifier).loadFromStorage();
              } catch (_) {}
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await DioClient().dio.post(ApiEndpoints.logout);
              } catch (_) {}
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

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? titleColor;
  final Widget? trailing;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: TextStyle(color: titleColor)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
