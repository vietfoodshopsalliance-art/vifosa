// mobile/lib/shared/widgets/role_switcher_dropdown.dart
//
// Dropdown header widget — hiện nickname + avatar, cho phép chuyển dashboard
// theo role. Dùng trong AppBar của HomeScreen và mọi screen cần role switch.
//
// Usage:
//   AppBar(actions: [const RoleSwitcherDropdown()])

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model & Provider — thay bằng authProvider thực từ module 01
// ─────────────────────────────────────────────────────────────────────────────

class UserSession {
  final String nickname;
  final String? avatarUrl;
  final List<String> roles; // ['customer', 'store_owner', 'admin', 'mod']

  const UserSession({
    required this.nickname,
    this.avatarUrl,
    required this.roles,
  });

  bool get isStoreOwner => roles.contains('store_owner');
  bool get isAdmin      => roles.contains('admin');
  bool get isMod        => roles.contains('mod');
}

// Stub — thay bằng authProvider thực (module 01)
final userSessionProvider = Provider<UserSession?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Dropdown widget
// ─────────────────────────────────────────────────────────────────────────────

class RoleSwitcherDropdown extends ConsumerWidget {
  const RoleSwitcherDropdown({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(userSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<_RoleAction>(
        onSelected: (action) => _handleAction(context, action),
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        itemBuilder: (_) => _buildMenuItems(session),
        // ── Trigger (nickname + avatar) ──────────────────────────────
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(url: session.avatarUrl, nickname: session.nickname),
            const SizedBox(width: 6),
            Text(
              session.nickname,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }

  // ── Menu items ────────────────────────────────────────────────────────────

  List<PopupMenuEntry<_RoleAction>> _buildMenuItems(UserSession session) {
    return [
      // Header info (non-clickable)
      PopupMenuItem<_RoleAction>(
        enabled: false,
        height: 52,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              session.nickname,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 2),
            Text(
              _roleLabel(session.roles),
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
          ],
        ),
      ),
      const PopupMenuDivider(),

      // Customer (luôn có)
      _item(_RoleAction.customer, Icons.person_rounded, 'Tài khoản khách hàng'),

      // Store owner
      if (session.isStoreOwner)
        _item(_RoleAction.storeOwner, Icons.storefront_rounded, 'Dashboard quán'),

      // Mod
      if (session.isMod)
        _item(_RoleAction.mod, Icons.shield_outlined, 'Mod Dashboard'),

      // Admin
      if (session.isAdmin)
        _item(_RoleAction.admin, Icons.admin_panel_settings_rounded,
            'Admin Dashboard'),

      const PopupMenuDivider(),
      _item(_RoleAction.editProfile, Icons.manage_accounts_rounded,
          'Chỉnh sửa hồ sơ'),
      _item(_RoleAction.logout, Icons.logout_rounded, 'Đăng xuất',
          isDestructive: true),
    ];
  }

  PopupMenuItem<_RoleAction> _item(
    _RoleAction action,
    IconData icon,
    String label, {
    bool isDestructive = false,
  }) {
    final color =
        isDestructive ? const Color(0xFFEF4444) : const Color(0xFF374151);
    return PopupMenuItem<_RoleAction>(
      value: action,
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

  // ── Navigation logic ──────────────────────────────────────────────────────

  void _handleAction(BuildContext context, _RoleAction action) {
    switch (action) {
      case _RoleAction.customer:
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
      case _RoleAction.storeOwner:
        // Nhiều quán → MyStoresScreen để chọn; 1 quán → thẳng dashboard
        Navigator.pushNamed(context, '/my-stores');
      case _RoleAction.mod:
        Navigator.pushNamed(context, '/mod/dashboard');
      case _RoleAction.admin:
        Navigator.pushNamed(context, '/admin/dashboard');
      case _RoleAction.editProfile:
        Navigator.pushNamed(context, '/profile/edit');
      case _RoleAction.logout:
        _confirmLogout(context);
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              Navigator.pop(context);
              // TODO: ref.read(authProvider.notifier).logout()
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (_) => false);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  String _roleLabel(List<String> roles) {
    if (roles.contains('admin'))       return 'Quản trị viên';
    if (roles.contains('mod'))         return 'Kiểm duyệt viên';
    if (roles.contains('store_owner')) return 'Chủ quán';
    return 'Khách hàng';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar — fallback = chữ cái đầu nickname trên màu deterministic
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? url;
  final String nickname;
  const _Avatar({this.url, required this.nickname});

  static const _colors = [
    Color(0xFF2563EB),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      // Cloudinary transform: w_80,h_80,c_fill,g_face,f_auto,q_auto
      final transformed = url!.replaceFirst(
          '/upload/', '/upload/w_80,h_80,c_fill,g_face,f_auto,q_auto/');
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(transformed),
      );
    }

    final initial = nickname.isNotEmpty ? nickname[0].toUpperCase() : '?';
    final color = _colors[nickname.codeUnitAt(0) % _colors.length];

    return CircleAvatar(
      radius: 16,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum
// ─────────────────────────────────────────────────────────────────────────────

enum _RoleAction { customer, storeOwner, mod, admin, editProfile, logout }