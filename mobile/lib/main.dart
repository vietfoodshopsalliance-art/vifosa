// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  container.read(authProvider);     // bắt đầu _init() kiểm tra token
  container.read(appRouterProvider); // gắn listener vào authProvider ngay

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VifosaApp(),
    ),
  );
}

class VifosaApp extends ConsumerWidget {
  const VifosaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Vifosa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
