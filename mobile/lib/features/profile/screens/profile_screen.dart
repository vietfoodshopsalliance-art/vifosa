// lib/features/profile/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vifosa/features/auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user ?? {};

    final roles = (user['roles'] as List<dynamic>? ?? []).cast<String>();
    final isStoreOwner = roles.contains('store_owner');
    final avatarUrl = user['avatarImage'] as String?;
    final nickname = user['nickname'] as String? ?? '';
    final username = user['username'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Hồ sơ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 48,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      (nickname.isNotEmpty ? nickname : 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
            const SizedBox(height: 16),

            // Nickname
            Text(
              nickname,
              style: Theme.of(context).textTheme.titleLarge,
            ),

            // Username
            Text(
              '@$username',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 8),

            // Roles badge
            Wrap(
              spacing: 6,
              children: roles.map((r) => Chip(label: Text(r))).toList(),
            ),

            const SizedBox(height: 24),

            // Store owner shortcut
            if (isStoreOwner)
              ElevatedButton.icon(
                icon: const Icon(Icons.store),
                label: const Text('Quản lý quán'),
                onPressed: () => context.push('/my-stores'),
              ),

            const Spacer(),

            OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Đăng xuất',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () => _confirmLogout(context, ref),
            ),

            const SizedBox(height: 16),
          ],
        ),
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
            child: const Text('Đăng xuất',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
