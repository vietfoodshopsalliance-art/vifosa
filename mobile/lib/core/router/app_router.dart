// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/order/screens/orders_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/address_list_screen.dart';
import '../../features/profile/screens/payment_methods_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/my_reviews_screen.dart';
import '../../features/profile/screens/support_ticket_screen.dart';
import '../../features/store_dashboard/screens/store_dashboard.dart';
import '../../features/store/screens/create_store_screen.dart';
import '../../features/store_dashboard/screens/store_orders.dart';
import '../../features/store_dashboard/screens/store_menu.dart';
import '../../features/store_dashboard/settings/store_settings_screen.dart';
import '../../features/store_dashboard/reviews/store_reviews_screen.dart';
import '../../features/store_dashboard/screens/store_manage_screen.dart';
import '../../features/profile/screens/favorites_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/store_detail/screens/store_detail_screen.dart';
import '../../features/order/screens/order_tracking_screen.dart';
import '../../features/order/screens/checkout_screen.dart';
import '../widgets/scaffold_with_nav.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier._redirect,
    initialLocation: '/login',
    routes: [
      // ── Auth (không có bottom nav) ────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ── Shell: màn hình có Bottom Navigation Bar ──────────────────────────
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (_, __) => const CartScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),

      // ── Notifications ─────────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),

      // ── Profile sub-screens ───────────────────────────────────────────────
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, __) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/profile/payment-methods',
        builder: (_, __) => const PaymentMethodsScreen(),
      ),
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile/my-reviews',
        builder: (_, __) => const MyReviewsScreen(),
      ),
      GoRoute(
        path: '/profile/my-rating',
        builder: (_, __) => const MyRatingScreen(),
      ),
      GoRoute(
        path: '/profile/support',
        builder: (_, __) => const SupportTicketScreen(),
      ),

      // ── Favorites ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/favorites',
        builder: (_, __) => const FavoritesScreen(),
      ),

      // ── Store ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/store/create',
        builder: (_, __) => const CreateStoreScreen(),
      ),
      GoRoute(
        path: '/store/:id',
        builder: (_, state) => StoreDetailScreen(
          storeId: state.pathParameters['id']!,
        ),
      ),

      // ── Checkout & Orders ─────────────────────────────────────────────────
      GoRoute(
        path: '/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => OrderTrackingScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),

      // ── Store Dashboard ───────────────────────────────────────────────────
      GoRoute(
        path: '/my-stores',
        builder: (_, __) => const StoreDashboardScreen(),
      ),
      GoRoute(
        path: '/store-dashboard',
        builder: (_, __) => const StoreDashboardScreen(),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/orders',
        builder: (_, state) => StoreOrdersScreen(
          storeId: state.pathParameters['storeId']!,
        ),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/menu',
        builder: (_, state) => StoreMenuScreen(
          storeId: state.pathParameters['storeId']!,
        ),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/settings',
        builder: (_, state) => StoreSettingsScreen(
          storeId: state.pathParameters['storeId']!,
        ),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/reviews',
        builder: (_, state) => StoreReviewsScreen(
          storeId: state.pathParameters['storeId']!,
        ),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/manage',
        builder: (_, state) => StoreManageScreen(
          storeId: state.pathParameters['storeId']!,
        ),
      ),

      // ── Admin (placeholder) ───────────────────────────────────────────────
      GoRoute(
        path: '/admin',
        builder: (_, __) => const _PlaceholderScreen(title: 'Admin Dashboard'),
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? _redirect(BuildContext context, GoRouterState state) {
    final auth = _ref.read(authProvider);
    if (auth.isLoading) return null;

    final loc = state.matchedLocation;
    final isPublic = loc == '/login' || loc == '/register';

    if (!auth.isAuthenticated && !isPublic) return '/login';
    if (auth.isAuthenticated && isPublic) return '/home';
    return null;
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
