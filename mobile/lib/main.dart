// lib/main.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Bắt tất cả lỗi Flutter framework
  FlutterError.onError = (details) {
    debugPrint('══ FlutterError ══');
    debugPrint('${details.exceptionAsString()}');
    debugPrint('${details.stack}');
  };

  runZonedGuarded(
    () async {
      final container = ProviderContainer();
      container.read(authProvider);
      container.read(appRouterProvider);

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const VifosaApp(),
        ),
      );
    },
    // Bắt mọi lỗi async không được xử lý
    (error, stack) {
      debugPrint('══ UNHANDLED ASYNC ERROR ══');
      debugPrint('Type : ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrint('Stack:\n$stack');
    },
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
