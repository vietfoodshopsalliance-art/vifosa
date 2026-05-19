// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/home/screens/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    refreshListenable: notifier,
    redirect: notifier._redirect,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) =>
            const _PlaceholderScreen(title: 'Thông báo'),
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) => _PlaceholderScreen(
          title: 'Đơn hàng ${state.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/social/post/:id',
        builder: (_, state) => _PlaceholderScreen(
          title: 'Bài viết ${state.pathParameters['id']}',
        ),
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

    final isPublic =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!auth.isAuthenticated && !isPublic) return '/login';
    if (auth.isAuthenticated && isPublic) return '/';
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
