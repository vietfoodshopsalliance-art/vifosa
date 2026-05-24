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
  bool _minTimeElapsed = false;
  AuthStatus? _pendingStatus;

  void _navigate(AuthStatus status) {
    if (_navigated || !mounted) return;
    // Chờ đủ thời gian tối thiểu mới navigate
    if (!_minTimeElapsed) {
      _pendingStatus = status;
      return;
    }
    _navigated = true;
    context.go('/home');
  }

  @override
  void initState() {
    super.initState();

    // Thời gian tối thiểu 2 giây để logo hiển thị
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _minTimeElapsed = true;
      if (_pendingStatus != null) {
        _navigate(_pendingStatus!);
      }
    });

    // Safety timer — 6s fallback
    Future.delayed(const Duration(seconds: 6), () {
      if (!_navigated && mounted) {
        _minTimeElapsed = true;
        final status = ref.read(authProvider).status;
        _navigate(status == AuthStatus.authenticated
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated);
      }
    });

    // Check ngay sau frame đầu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final status = ref.read(authProvider).status;
      if (status != AuthStatus.loading) {
        _navigate(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.status != AuthStatus.loading) {
        _navigate(next.status);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4B400),
      body: Center(
        child: Image.asset(
          'assets/images/splash_logo.png',
          width: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
