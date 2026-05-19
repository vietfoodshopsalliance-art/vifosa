// lib/features/store_dashboard/store_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/socket_client.dart';
import 'orders/store_orders_provider.dart';
import 'orders/store_orders_screen.dart';
import 'menu/store_menu_screen.dart';
import 'settings/store_settings_screen.dart';
import 'reviews/store_reviews_screen.dart';

// ─── Provider: store info ────────────────────────────────────────────────────

final storeInfoProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, String>(
  (ref, storeId) async {
    final dio = ref.read(dioClientProvider);
    final res = await dio.get(ApiEndpoints.storeById(storeId));
    return res.data as Map<String, dynamic>;
  },
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class StoreDashboardScreen extends ConsumerStatefulWidget {
  final String storeId;
  final int initialTab;

  const StoreDashboardScreen({
    super.key,
    required this.storeId,
    this.initialTab = 0,
  });

  @override
  ConsumerState<StoreDashboardScreen> createState() =>
      _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends ConsumerState<StoreDashboardScreen> {
  late int _currentTab;
  String? _bannerMessage;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _joinSocket();
  }

  void _joinSocket() {
    final socket = SocketClient();
    socket.joinStore(widget.storeId);

    socket.on('new_order', (data) {
      if (!mounted) return;
      ref.refresh(storeOrdersProvider(widget.storeId));
      final code = (data as Map?)?['code'] ?? '';
      _showBanner('🛵 Đơn mới! #$code');
    });

    socket.on('order_status_changed', (_) {
      if (!mounted) return;
      ref.refresh(storeOrdersProvider(widget.storeId));
    });

    socket.on('order_deadline', (data) {
      if (!mounted) return;
      final code = (data as Map?)?['code'] ?? '';
      _showBanner('⚠️ Đơn #$code sắp bị tự huỷ!');
    });

    socket.on('payment_action', (_) {
      if (!mounted) return;
      _showBanner('💳 Khách báo sai: tiền chưa vào TK');
    });

    socket.on('refund_alert', (data) {
      if (!mounted) return;
      final hours = (data as Map?)?['hours'] ?? '';
      _showBanner('🔄 Cần hoàn tiền trong $hours giờ');
    });

    socket.on('review', (_) {
      if (!mounted) return;
      _showBanner('⭐ Có đánh giá mới');
    });

    socket.on('account_critical', (data) {
      if (!mounted) return;
      _showAccountCriticalDialog(
          (data as Map?)?['message'] as String? ?? 'Cảnh báo tài khoản');
    });
  }

  void _showBanner(String message) {
    setState(() => _bannerMessage = message);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  void _showAccountCriticalDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cảnh báo tài khoản'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    SocketClient().leaveStore(widget.storeId);
    super.dispose();
  }

  static const _tabs = [
    _TabItem(icon: Icons.inventory_2_outlined, label: 'Đơn hàng'),
    _TabItem(icon: Icons.restaurant_menu_outlined, label: 'Menu'),
    _TabItem(icon: Icons.settings_outlined, label: 'Cài đặt'),
    _TabItem(icon: Icons.star_outline, label: 'Đánh giá'),
  ];

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeInfoProvider(widget.storeId));

    final storeName =
        storeAsync.valueOrNull?['name'] as String? ?? 'Quản lý quán';
    final isOpen = storeAsync.valueOrNull?['isOpen'] as bool? ?? false;
    final emergencyClosed =
        storeAsync.valueOrNull?['emergencyClosed'] as bool? ?? false;
    final statusOpen = isOpen && !emergencyClosed;

    final ordersAsync = ref.watch(storeOrdersProvider(widget.storeId));
    final pendingCount =
        ordersAsync.valueOrNull?.pendingOrders.length ?? 0;

    final pages = [
      StoreOrdersScreen(storeId: widget.storeId),
      StoreMenuScreen(storeId: widget.storeId),
      StoreSettingsScreen(storeId: widget.storeId),
      StoreReviewsScreen(storeId: widget.storeId),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Đổi quán',
          onPressed: () => context.go('/store-dashboard'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                storeName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(isOpen: statusOpen),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentTab,
            children: pages,
          ),
          if (_bannerMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NotificationBanner(message: _bannerMessage!),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.inventory_2),
            ),
            label: 'Đơn hàng',
          ),
          const NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
          const NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Đánh giá',
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;
  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withOpacity(0.15)
            : Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOpen ? 'Đang mở' : 'Tạm đóng',
        style: TextStyle(
          color: isOpen ? Colors.green.shade700 : Colors.orange.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  final String message;
  const _NotificationBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.inverseSurface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
