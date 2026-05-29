// lib/main.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try { await Firebase.initializeApp(); } catch (_) {}
}

void main() {
  // runZonedGuarded phải bọc toàn bộ — kể cả ensureInitialized —
  // để binding và runApp cùng nằm trong một zone, tránh "Zone mismatch".
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      } catch (_) {}
      await Hive.initFlutter();
      await MobileAds.instance.initialize();

      // Preload splash image vào cache trước khi runApp
      final splashCompleter = Completer<void>();
      const AssetImage('assets/images/splash_logo.png')
          .resolve(ImageConfiguration.empty)
          .addListener(ImageStreamListener(
            (_, __) { if (!splashCompleter.isCompleted) splashCompleter.complete(); },
            onError: (_, __) { if (!splashCompleter.isCompleted) splashCompleter.complete(); },
          ));
      await splashCompleter.future;

      // Bắt tất cả lỗi Flutter framework
      FlutterError.onError = (details) {
        debugPrint('══ FlutterError ══');
        debugPrint('${details.exceptionAsString()}');
        debugPrint('${details.stack}');
      };

      final container = ProviderContainer();
      container.read(authProvider);
      container.read(appRouterProvider);

      // Khi user đăng nhập thành công, lấy FCM token và gửi lên backend
      container.listen<AuthState>(authProvider, (prev, next) {
        if (next.status == AuthStatus.authenticated &&
            prev?.status != AuthStatus.authenticated) {
          FirebaseMessaging.instance
              .requestPermission(provisional: true)
              .then((_) => FirebaseMessaging.instance.getToken())
              .then((token) {
            if (token != null) {
              container.read(authProvider.notifier).saveFcmToken(token);
            }
          }).catchError((_) {});
        }
      });

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
