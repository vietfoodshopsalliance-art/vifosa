import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase.initializeApp() se them tuan 1 ngay 6 (spec TO-7)
  runApp(const ProviderScope(child: VifosaApp()));
}

class VifosaApp extends ConsumerStatefulWidget {
  const VifosaApp({super.key});
  @override
  ConsumerState<VifosaApp> createState() => _VifosaAppState();
}

class _VifosaAppState extends ConsumerState<VifosaApp> {
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= GoRouter(
      initialLocation: '/login',
      refreshListenable: _AuthListenable(ProviderScope.containerOf(context)),
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isAuth = authState.status == AuthStatus.authenticated;
        final onAuthPage = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        if (!isAuth && !onAuthPage) return '/login';
        if (isAuth && onAuthPage) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login',    builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/home',     builder: (_, __) => const _HomePlaceholder()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Viet Food Shops Alliance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      routerConfig: _router!,
    );
  }
}

// --- Home placeholder — tuan 6 se thay bang HomeScreen that ---
class _HomePlaceholder extends ConsumerWidget {
  const _HomePlaceholder();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final nickname = user?['nickname'] ?? user?['username'] ?? 'ban';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vifosa'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
            tooltip: 'Dang xuat',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant, size: 80, color: Colors.orange),
            const SizedBox(height: 16),
            Text('Chao $nickname!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Home screen - Tuan 6',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// --- Ket noi Riverpod state voi GoRouter refresh ---
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(ProviderContainer container) {
    _sub = container.listen(authProvider, (_, __) => notifyListeners());
  }

  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}