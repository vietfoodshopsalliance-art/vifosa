// lib/core/widgets/avatar_menu_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';

enum AvatarMenuOption { profile, storeDashboard, logout }

class AvatarMenuButton extends ConsumerWidget {
  final Map<String, dynamic>? user;
  const AvatarMenuButton({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nickname = user?['nickname'] as String? ??
        user?['username'] as String? ??
        '';
    final avatarUrl =
        user?['avatarImage'] as String? ?? user?['avatar'] as String?;

    return PopupMenuButton<AvatarMenuOption>(
      offset: const Offset(0, 50),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (option) => _onSelected(context, ref, option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _buildAvatar(avatarUrl, nickname),
      ),
      itemBuilder: (_) => [
        _menuItem(AvatarMenuOption.profile, Icons.person_outline, 'Profile'),
        _menuItem(AvatarMenuOption.storeDashboard, Icons.storefront_outlined,
            'Quản lý quán'),
        const PopupMenuDivider(),
        _menuItem(AvatarMenuOption.logout, Icons.logout_rounded, 'Thoát',
            destructive: true),
      ],
    );
  }

  PopupMenuItem<AvatarMenuOption> _menuItem(
    AvatarMenuOption option,
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

  void _onSelected(
      BuildContext context, WidgetRef ref, AvatarMenuOption option) {
    switch (option) {
      case AvatarMenuOption.profile:
        context.push('/profile');
      case AvatarMenuOption.storeDashboard:
        context.push('/my-stores');
      case AvatarMenuOption.logout:
        ref.read(authProvider.notifier).logout();
    }
  }
}
