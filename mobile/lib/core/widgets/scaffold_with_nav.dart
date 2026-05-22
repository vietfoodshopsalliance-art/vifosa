import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/screens/cart_screen.dart';

class ScaffoldWithNav extends ConsumerWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  static const _routes = ['/home', '/search', '/cart', '/orders', '/profile'];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _routes.indexWhere((r) => loc.startsWith(r));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider.select((s) => s.totalItems));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => context.go(_routes[i]),
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
