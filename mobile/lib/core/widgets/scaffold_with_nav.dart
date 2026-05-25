import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/screens/cart_screen.dart';

class ScaffoldWithNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ScaffoldWithNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((s) => s.totalItems));

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Tìm kiếm',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text(cartCount > 99 ? '99+' : '$cartCount'),
              isLabelVisible: cartCount > 0,
              backgroundColor: const Color(0xFFE53935),
              textColor: Colors.white,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            selectedIcon: Badge(
              label: Text(cartCount > 99 ? '99+' : '$cartCount'),
              isLabelVisible: cartCount > 0,
              backgroundColor: const Color(0xFFE53935),
              textColor: Colors.white,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Giỏ hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
