// lib/main.dart
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/router/app_router.dart';
import 'core/services/token_service.dart';
import 'core/services/token_service_impl.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/notifications/widgets/in_app_banner.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB

PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('════════ PLATFORM ERROR ════════');
    debugPrint('$error');
    // Lọc chỉ dòng có vifosa hoặc features
    final frames = stack.toString().split('\n');
    for (final f in frames) {
      if (f.contains('vifosa') || f.contains('features') || f.contains('lib/')) {
        debugPrint('>>> $f');
      }
    }
    debugPrint('════════════════════════════════');
    return true;
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('════════════ FLUTTER ERROR ════════════');
    debugPrint('EXCEPTION: ${details.exception}');
    debugPrint('LIBRARY: ${details.library}');
    debugPrint('CONTEXT: ${details.context}');
    debugPrint('STACK:');
    // In từng frame một để không bị cắt
    final frames = details.stack.toString().split('\n');
    for (var i = 0; i < frames.length; i++) {
      debugPrint('  #$i ${frames[i]}');
    }
    debugPrint('═══════════════════════════════════════');
  };

  await Hive.initFlutter();
  await Hive.openBox('guest_cart');
  await Hive.openBox('menu_prefs');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Tạo container thủ công để warm-up đúng thứ tự:
  // 1. authProvider tạo ra, bắt đầu _tryRestoreSession() (async)
  // 2. appRouterProvider tạo ra, _RouterNotifier gắn ref.listen vào authProvider
  // 3. Khi _tryRestoreSession() resolve → notifyListeners() → GoRouter redirect
  final container = ProviderContainer(
    overrides: [
      tokenServiceProvider.overrideWithValue(TokenServiceImpl()),
    ],
  );
  container.read(authProvider);    // khởi tạo auth (bắt đầu chạy async)
  container.read(appRouterProvider); // khởi tạo router, gắn listener ngay

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VifosaApp(),
    ),
  );
}

class VifosaApp extends ConsumerStatefulWidget {
  const VifosaApp({super.key});

  @override
  ConsumerState<VifosaApp> createState() => _VifosaAppState();
}

class _VifosaAppState extends ConsumerState<VifosaApp> {
  @override
  void initState() {
    super.initState();
    _initFcm();
  }

  Future<void> _initFcm() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((msg) {
      ref.read(notificationProvider.notifier).handleIncomingMessage(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _navigateFromMessage(initial),
      );
    }

    messaging.onTokenRefresh.listen(
      (token) => ref.read(authProvider.notifier).updateFcmToken(token),
    );
  }

  void _navigateFromMessage(RemoteMessage message) {
    final router = ref.read(appRouterProvider);
    final data = message.data;
    switch (data['type']) {
      case 'order_update':
        router.push('/order/${data['orderId']}');
      case 'social':
        router.push('/social/post/${data['postId']}');
      default:
        router.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Vifosa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => InAppNotificationOverlay(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
