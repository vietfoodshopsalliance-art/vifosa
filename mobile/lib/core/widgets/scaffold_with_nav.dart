import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/screens/cart_screen.dart';
import '../../features/home/screens/home_screen.dart';

class ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((s) => s.totalItems));
    final currentIndex = navigationShell.currentIndex;

    void goTo(int i) => navigationShell.goBranch(
          i,
          initialLocation: i == currentIndex,
        );

    void scrollToTop() => ref.read(homeScrollToTopProvider.notifier).state++;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _CustomNavBar(
        currentIndex: currentIndex,
        cartCount: cartCount,
        onBranchSelected: goTo,
        onScrollToTop: scrollToTop,
      ),
    );
  }
}

// ── Custom bottom nav bar ─────────────────────────────────────────────────────

class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final void Function(int) onBranchSelected;
  final VoidCallback onScrollToTop;

  const _CustomNavBar({
    required this.currentIndex,
    required this.cartCount,
    required this.onBranchSelected,
    required this.onScrollToTop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // ── Trang chủ (luôn hiện dropdown khi tap) ──────────────────
              Builder(builder: (ctx) {
                return _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Trang chủ',
                  selected: currentIndex == 0,
                  onTap: () => _showHomeMenu(ctx),
                );
              }),

              // ── Quán ────────────────────────────────────────────────────
              _NavItem(
                icon: Icons.storefront_outlined,
                selectedIcon: Icons.storefront_rounded,
                label: 'Quán',
                selected: currentIndex == 1,
                onTap: () => onBranchSelected(1),
              ),

              // ── Giỏ hàng ────────────────────────────────────────────────
              _CartNavItem(
                cartCount: cartCount,
                selected: currentIndex == 2,
                onTap: () => onBranchSelected(2),
              ),

              // ── Đơn hàng ────────────────────────────────────────────────
              _NavItem(
                icon: Icons.receipt_long_outlined,
                selectedIcon: Icons.receipt_long_rounded,
                label: 'Đơn hàng',
                selected: currentIndex == 3,
                onTap: () => onBranchSelected(3),
              ),

              // ── Cá nhân ─────────────────────────────────────────────────
              _NavItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Cá nhân',
                selected: currentIndex == 4,
                onTap: () => onBranchSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHomeMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(
            box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: pos,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      items: [
        _menuItem('home', Icons.home_rounded, 'Trang chủ'),
        _menuItem('search', Icons.search_rounded, 'Tìm kiếm'),
        const PopupMenuDivider(height: 1),
        _menuItemComingSoon(
            'trending', Icons.local_fire_department_rounded, 'Món bán chạy'),
        _menuItemComingSoon(
            'top_rated', Icons.star_rounded, 'Món điểm cao'),
        _menuItemComingSoon(
            'promo', Icons.local_offer_rounded, 'Món khuyến mãi'),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'home':
          if (currentIndex != 0) {
            onBranchSelected(0);
          } else {
            onScrollToTop();
          }
        case 'search':
          context.push('/search');
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tính năng sắp ra mắt!'),
              backgroundColor: const Color(0xFFF4B400),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    });
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF374151)),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItemComingSoon(
      String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black38),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF4B400).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Sắp ra',
              style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFFF4B400),
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Standard nav item ─────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 24,
              color: selected ? const Color(0xFFF4B400) : Colors.black54,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? const Color(0xFFF4B400) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cart nav item (với badge số lượng) ───────────────────────────────────────

class _CartNavItem extends StatelessWidget {
  final int cartCount;
  final bool selected;
  final VoidCallback onTap;

  const _CartNavItem({
    required this.cartCount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              label: Text(
                cartCount > 99 ? '99+' : '$cartCount',
                style: const TextStyle(fontSize: 9),
              ),
              isLabelVisible: cartCount > 0,
              backgroundColor: const Color(0xFFE53935),
              textColor: Colors.white,
              child: Icon(
                selected
                    ? Icons.shopping_cart_rounded
                    : Icons.shopping_cart_outlined,
                size: 24,
                color: selected ? const Color(0xFFF4B400) : Colors.black54,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Giỏ hàng',
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? const Color(0xFFF4B400) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
