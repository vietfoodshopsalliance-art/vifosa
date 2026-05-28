// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/stores/screens/stores_screen.dart';
import '../../features/cart/screens/cart_screen.dart';
import '../../features/order/screens/orders_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/profile/screens/address_list_screen.dart';
import '../../features/profile/screens/payment_methods_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/reviews/screens/my_reviews_screen.dart';
import '../../features/profile/screens/support_ticket_screen.dart';
import '../../features/profile/screens/support_us_screen.dart';
import '../../features/store_dashboard/screens/store_dashboard.dart';
import '../../features/store/screens/create_store_screen.dart';
import '../../features/store_dashboard/screens/store_orders.dart';
import '../../features/store_dashboard/screens/store_menu.dart';
import '../../features/store_dashboard/settings/store_settings_screen.dart';
import '../../features/store_dashboard/reviews/store_reviews_screen.dart';
import '../../features/store_dashboard/screens/store_manage_screen.dart';
import '../../features/store_dashboard/screens/store_reports_screen.dart';
import '../../features/store_dashboard/screens/customer_profile_screen.dart';
import '../../features/profile/screens/favorites_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/store_detail/screens/store_detail_screen.dart';
import '../../features/store_detail/screens/item_detail_screen.dart';
import '../models/category.dart';
import '../models/store.dart' show StoreStatus;
import '../../features/order/screens/order_tracking_screen.dart';
import '../../features/order/screens/checkout_screen.dart';
import '../../features/order/screens/guest_tracking_screen.dart';
import '../../features/order/screens/guest_checkout_screen.dart';
import '../../features/order/screens/guest_order_success_screen.dart';
import '../widgets/scaffold_with_nav.dart';

// Buộc light theme cho màn hình store dashboard (kể cả bottom sheet, dialog mở từ trong)
Widget _light(Widget child) => Theme(data: AppTheme.light, child: child);

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier._redirect,
    initialLocation: '/splash',
    routes: [
      // ── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth (không có bottom nav) ────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => _light(const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => _light(const RegisterScreen()),
      ),

      // ── Search (push route, không thuộc shell) ────────────────────────────
      GoRoute(
        path: '/search',
        builder: (_, __) => _light(const SearchScreen()),
      ),

      // ── Shell: màn hình có Bottom Navigation Bar ──────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          // 0 - Trang chủ
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          // 1 - Quán
          StatefulShellBranch(routes: [
            GoRoute(path: '/stores', builder: (_, __) => const StoresScreen()),
          ]),
          // 2 - Giỏ hàng
          StatefulShellBranch(routes: [
            GoRoute(path: '/cart', builder: (_, __) => _light(const CartScreen())),
          ]),
          // 3 - Đơn hàng
          StatefulShellBranch(routes: [
            GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          ]),
          // 4 - Cá nhân
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),

      // ── Notifications ─────────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, __) => _light(const NotificationsScreen()),
      ),

      // ── Profile sub-screens ───────────────────────────────────────────────
      GoRoute(
        path: '/profile/edit',
        builder: (_, __) => _light(const EditProfileScreen()),
      ),
      GoRoute(
        path: '/profile/addresses',
        builder: (_, __) => _light(const AddressListScreen()),
      ),
      GoRoute(
        path: '/profile/payment-methods',
        builder: (_, __) => _light(const PaymentMethodsScreen()),
      ),
      GoRoute(
        path: '/profile/settings',
        builder: (_, __) => _light(const SettingsScreen()),
      ),
      GoRoute(
        path: '/profile/my-reviews',
        builder: (_, __) => _light(const MyReviewsScreen()),
      ),
      GoRoute(
        path: '/profile/my-rating',
        builder: (_, __) => _light(const MyRatingScreen()),
      ),
      GoRoute(
        path: '/profile/support',
        builder: (_, __) => _light(const SupportTicketScreen()),
      ),
      GoRoute(
        path: '/profile/support-us',
        builder: (_, __) => _light(const SupportUsScreen()),
      ),

      // ── Favorites ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/favorites',
        builder: (_, __) => _light(const FavoritesScreen()),
      ),

      // ── Store ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/store/create',
        builder: (_, __) => _light(const CreateStoreScreen()),
      ),
      GoRoute(
        path: '/store/:id',
        builder: (_, state) => _light(StoreDetailScreen(
          storeId: state.pathParameters['id']!,
        )),
      ),
      GoRoute(
        path: '/item-detail',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _light(ItemDetailScreen(
            item: extra['item'] as CategoryItem,
            storeId: extra['storeId'] as String,
            storeName: extra['storeName'] as String,
            storeStatus: extra['storeStatus'] as StoreStatus,
          ));
        },
      ),

      // ── Checkout & Orders ─────────────────────────────────────────────────
      GoRoute(
        path: '/checkout',
        builder: (_, __) => _light(const CheckoutScreen()),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => _light(OrderTrackingScreen(
          orderId: state.pathParameters['id']!,
        )),
      ),

      // ── Guest ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/track',
        builder: (_, state) => _light(GuestTrackingScreen(
          orderCode: state.uri.queryParameters['code'] ?? '',
          token: state.uri.queryParameters['t'],
        )),
      ),
      GoRoute(
        path: '/guest-checkout',
        builder: (_, state) {
          final args = state.extra as GuestCheckoutArgs;
          return _light(GuestCheckoutScreen(args: args));
        },
      ),
      GoRoute(
        path: '/guest-order-success',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return _light(GuestOrderSuccessScreen(
            orderId:          extra['orderId'] as String? ?? '',
            code:             extra['code'] as String,
            token:            extra['token'] as String,
            storeName:        extra['storeName'] as String,
            storeBankAccount: extra['storeBankAccount'] as Map<String, dynamic>?,
            storeVipTier:     extra['storeVipTier'] as String? ?? 'none',
            totalAmount:      (extra['totalAmount'] as num).toInt(),
          ));
        },
      ),

      // ── Store Dashboard ───────────────────────────────────────────────────
      GoRoute(
        path: '/my-stores',
        builder: (_, __) => _light(const StoreDashboardScreen()),
      ),
      GoRoute(
        path: '/store-dashboard',
        builder: (_, __) => _light(const StoreDashboardScreen()),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/orders',
        builder: (_, state) => _light(StoreOrdersScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/menu',
        builder: (_, state) => _light(StoreMenuScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/settings',
        builder: (_, state) => _light(StoreSettingsScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/reviews',
        builder: (_, state) => _light(StoreReviewsScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/manage',
        builder: (_, state) => _light(StoreManageScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/reports',
        builder: (_, state) => _light(StoreReportsScreen(
          storeId: state.pathParameters['storeId']!,
        )),
      ),
      GoRoute(
        path: '/store-dashboard/:storeId/customers/:customerId',
        builder: (_, state) => _light(CustomerProfileScreen(
          storeId: state.pathParameters['storeId']!,
          customerId: state.pathParameters['customerId']!,
        )),
      ),

      // ── Admin ─────────────────────────────────────────────────────────────
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

    if (auth.isAuthenticated && (loc == '/login' || loc == '/register')) {
      return '/home';
    }

    const protectedPrefixes = [
      '/orders',
      '/profile',
      '/checkout',
      '/notifications',
      '/favorites',
      '/store/create',
      '/my-stores',
      '/store-dashboard',
      '/admin',
    ];

    final isProtected = protectedPrefixes.any(
      (p) => loc == p || loc.startsWith('$p/'),
    );

    if (!auth.isAuthenticated && isProtected) return '/login';

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
