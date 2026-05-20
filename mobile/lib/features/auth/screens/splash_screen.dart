// mobile/lib/features/auth/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _navigate(AuthStatus status) {
    if (_navigated || !mounted) return;
    _navigated = true;
    if (status == AuthStatus.authenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  void initState() {
    super.initState();

    // Safety timer — 6s fallback
    Future.delayed(const Duration(seconds: 6), () {
      if (!_navigated && mounted) {
        final status = ref.read(authProvider).status;
        _navigate(status == AuthStatus.authenticated
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated);
      }
    });

    // Check ngay sau frame đầu — bắt case auth đã resolve trước khi listen gắn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = ref.read(authProvider).status;
      if (status != AuthStatus.loading) {
        _navigate(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen để bắt case auth resolve SAU khi widget mount
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status != AuthStatus.loading) {
        _navigate(next.status);
      }
    });

    return const Scaffold(
      backgroundColor: Color(0xFFF4B400),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage('assets/images/app_icon.png'),
              width: 200,
              height: 200,
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}