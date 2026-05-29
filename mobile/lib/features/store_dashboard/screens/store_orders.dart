// lib/features/store_dashboard/screens/store_orders.dart
//
// Main store operating dashboard — 3 tabs: Chờ xử lý / Đang làm / Lịch sử
// Bottom nav: Dashboard / Menu / Đánh giá / Báo cáo / Quản lý

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_order.dart';
import '../orders/widgets/order_card_store.dart';
import '../orders/store_order_detail_screen.dart';

// ─── Error helper ─────────────────────────────────────────────────────────────

String _extractDioError(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
  }
  return e.toString();
}

// ─── Simple store info for switcher ──────────────────────────────────────────

class _SimpleStore {
  final String id;
  final String name;

  const _SimpleStore({required this.id, required this.name});
}

// ─── State ────────────────────────────────────────────────────────────────────

class StoreOrdersState {
  final List<StoreOrder> pendingOrders;
  final List<StoreOrder> inProgressOrders;
  final List<StoreOrder> historyOrders;
  final int historyCompleted;
  final int historyCancelled;
  final double historyRevenue;
  final String storeName;
  final bool isOpen;
  final bool emergencyClosed;
  final int autoCancelMinutes;
  final int autoConfirmMinutes;
  final int deliveryTimeoutMinutes;
  final bool isLoading;
  final String? error;
  final String historyFilter; // 'all' | 'completed' | 'cancelled' | 'check_payment'
  final String historySearch;
  final DateTime? historyDate;

  const StoreOrdersState({
    this.pendingOrders = const [],
    this.inProgressOrders = const [],
    this.historyOrders = const [],
    this.historyCompleted = 0,
    this.historyCancelled = 0,
    this.historyRevenue = 0,
    this.storeName = '',
    this.isOpen = true,
    this.emergencyClosed = false,
    this.autoCancelMinutes = 15,
    this.autoConfirmMinutes = 0,
    this.deliveryTimeoutMinutes = 180,
    this.isLoading = false,
    this.error,
    this.historyFilter = 'all',
    this.historySearch = '',
    this.historyDate,
  });

  int get pendingCount => pendingOrders.length;
  int get inProgressCount => inProgressOrders.length;

  List<StoreOrder> get filteredHistory {
    var list = historyOrders;
    if (historyFilter == 'completed') {
      list = list.where((o) => o.mainStatus == 'completed').toList();
    } else if (historyFilter == 'cancelled') {
      list = list.where((o) => o.mainStatus == 'cancelled').toList();
    } else if (historyFilter == 'check_payment') {
      list = list
          .where((o) =>
              o.mainStatus == 'completed' &&
              o.remainingAmount > 0)
          .toList();
    }
    if (historySearch.isNotEmpty) {
      final q = historySearch.toLowerCase();
      list = list.where((o) => o.code.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  StoreOrdersState copyWith({
    List<StoreOrder>? pendingOrders,
    List<StoreOrder>? inProgressOrders,
    List<StoreOrder>? historyOrders,
    int? historyCompleted,
    int? historyCancelled,
    double? historyRevenue,
    String? storeName,
    bool? isOpen,
    bool? emergencyClosed,
    int? autoCancelMinutes,
    int? autoConfirmMinutes,
    int? deliveryTimeoutMinutes,
    bool? isLoading,
    String? error,
    String? historyFilter,
    String? historySearch,
    Object? historyDate = _sentinel,
  }) =>
      StoreOrdersState(
        pendingOrders: pendingOrders ?? this.pendingOrders,
        inProgressOrders: inProgressOrders ?? this.inProgressOrders,
        historyOrders: historyOrders ?? this.historyOrders,
        historyCompleted: historyCompleted ?? this.historyCompleted,
        historyCancelled: historyCancelled ?? this.historyCancelled,
        historyRevenue: historyRevenue ?? this.historyRevenue,
        storeName: storeName ?? this.storeName,
        isOpen: isOpen ?? this.isOpen,
        emergencyClosed: emergencyClosed ?? this.emergencyClosed,
        autoCancelMinutes: autoCancelMinutes ?? this.autoCancelMinutes,
        autoConfirmMinutes: autoConfirmMinutes ?? this.autoConfirmMinutes,
        deliveryTimeoutMinutes:
            deliveryTimeoutMinutes ?? this.deliveryTimeoutMinutes,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        historyFilter: historyFilter ?? this.historyFilter,
        historySearch: historySearch ?? this.historySearch,
        historyDate: historyDate == _sentinel
            ? this.historyDate
            : historyDate as DateTime?,
      );
}

const _sentinel = Object();

// ─── Notifier ─────────────────────────────────────────────────────────────────

class StoreOrdersNotifier extends StateNotifier<StoreOrdersState> {
  final String storeId;

  StoreOrdersNotifier(this.storeId) : super(const StoreOrdersState()) {
    _fetchAll();
    _subscribeSocket();
  }

  void _subscribeSocket() {
    SocketClient().joinStore(storeId);
    SocketClient().on('new_order', (_) => fetchOrders());
    SocketClient().on('order_status_changed', (_) => fetchOrders());
  }

  @override
  void dispose() {
    SocketClient().leaveStore(storeId);
    SocketClient().off('new_order');
    SocketClient().off('order_status_changed');
    super.dispose();
  }

  Future<void> _fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await Future.wait([_fetchStoreInfo(), fetchOrders(), _fetchHistory()]);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return;
    }
    state = state.copyWith(isLoading: false);
  }

  Future<void> refresh() => _fetchAll();

  Future<void> _fetchStoreInfo() async {
    try {
      final res = await DioClient.instance
          .get(ApiEndpoints.myStoreById(storeId));
      final raw = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final d = (raw['store'] ?? raw) as Map<String, dynamic>;
      state = state.copyWith(
        storeName: d['name'] as String? ?? '',
        isOpen: d['isOpen'] as bool? ?? true,
        emergencyClosed: d['emergencyClosed'] as bool? ?? false,
        autoCancelMinutes: (d['autoCancelMinutes'] as num? ?? 15).toInt(),
        autoConfirmMinutes: (d['autoConfirmMinutes'] as num? ?? 0).toInt(),
        deliveryTimeoutMinutes:
            (d['deliveryTimeoutMinutes'] as num? ?? 180).toInt(),
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 403) {
        state = state.copyWith(error: 'Bạn không có quyền truy cập quán này');
      }
    }
  }

  Future<void> fetchOrders() async {
    try {
      final results = await Future.wait([
        _fetchTab('pending'),
        _fetchTab('active'),
      ]);

      final raw = results[0];
      // Sort: regular (non-preOrder) oldest-first, pre-orders at end
      final regular = raw.where((o) => !o.isPreOrder).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final preOrders = raw.where((o) => o.isPreOrder).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = state.copyWith(
        pendingOrders: [...regular, ...preOrders],
        inProgressOrders: results[1],
      );
    } catch (_) {}
  }

  Future<void> _fetchHistory([DateTime? date]) async {
    final d = date ?? state.historyDate ?? DateTime.now();
    final dayStart = DateTime(d.year, d.month, d.day);
    final dayEnd = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
    try {
      final orders = await _fetchTab('history', dateFrom: dayStart, dateTo: dayEnd);
      final completed = orders.where((o) => o.mainStatus == 'completed');
      final cancelled = orders.where((o) => o.mainStatus == 'cancelled');
      final revenue = completed.fold<double>(0, (sum, o) => sum + o.total);
      state = state.copyWith(
        historyOrders: orders,
        historyCompleted: completed.length,
        historyCancelled: cancelled.length,
        historyRevenue: revenue,
        historyDate: d,
      );
    } catch (_) {}
  }

  Future<List<StoreOrder>> _fetchTab(
    String tab, {
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, dynamic>{'tab': tab, 'limit': '50'};
    if (dateFrom != null) params['dateFrom'] = dateFrom.toUtc().toIso8601String();
    if (dateTo != null) params['dateTo'] = dateTo.toUtc().toIso8601String();
    final res = await DioClient.instance.get(
      ApiEndpoints.myStoreOrders(storeId),
      queryParameters: params,
    );
    final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = data['orders'] as List? ?? (res.data as List? ?? []);
    return list
        .map((e) => StoreOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// [open] = true  → mở cửa: clear emergencyClosed + set isOpen=true
  /// [open] = false → đóng cửa khẩn cấp
  Future<void> setStoreOpen(bool open) async {
    try {
      if (open) {
        await Future.wait([
          DioClient.instance.patch(
            ApiEndpoints.myStoreEmergencyClose(storeId),
            data: {'close': false},
          ),
          DioClient.instance.patch(
            ApiEndpoints.myStoreOpen(storeId),
            data: {'open': true},
          ),
        ]);
      } else {
        await DioClient.instance.patch(
          ApiEndpoints.myStoreEmergencyClose(storeId),
          data: {'close': true},
        );
      }
      await _fetchStoreInfo();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptOrder(String orderId) async {
    await DioClient.instance.patch(ApiEndpoints.orderAccept(orderId), data: {});
    await fetchOrders();
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    await DioClient.instance.patch(
      ApiEndpoints.orderReject(orderId),
      data: {'reason': reason.isEmpty ? 'Quán từ chối đơn' : reason},
    );
    await fetchOrders();
  }

  // preparing → delivering
  Future<void> startDelivery(String orderId) async {
    try {
      await DioClient.instance.patch(ApiEndpoints.orderDeliver(orderId), data: {});
    } finally {
      await fetchOrders();
    }
  }

  // delivering → delivered (quán xác nhận "đã trao hàng"); ghi nhận COD nếu có
  Future<void> markDelivered(String orderId) async {
    final order = state.inProgressOrders.where((o) => o.id == orderId).firstOrNull;
    try {
      await DioClient.instance.patch(ApiEndpoints.orderMarkDelivered(orderId), data: {});
      if (order != null &&
          order.remainingAmount > 0 &&
          (order.paymentMethod == 'cod' || order.paymentMethod == 'fifty_fifty')) {
        await DioClient.instance.patch(
          ApiEndpoints.orderConfirmMoney(orderId),
          data: {'amount': order.remainingAmount},
        );
      }
    } finally {
      await fetchOrders();
      await _fetchHistory();
    }
  }

  // Kept for backward compat — alias gọi startDelivery (preparing → delivering)
  Future<void> deliverOrder(String orderId) => startDelivery(orderId);

  Future<void> returnToPending(String orderId) async {
    try {
      await DioClient.instance
          .patch(ApiEndpoints.orderReturnToPending(orderId), data: {});
    } finally {
      await fetchOrders();
    }
  }

  Future<void> recordPayment(String orderId, double amount) async {
    await DioClient.instance.patch(
      ApiEndpoints.orderConfirmMoney(orderId),
      data: {'amount': amount},
    );
    await fetchOrders();
    await _fetchHistory();
  }

  void setHistoryFilter(String filter) {
    state = state.copyWith(historyFilter: filter, error: null);
  }

  void setHistorySearch(String q) {
    state = state.copyWith(historySearch: q, error: null);
  }

  Future<void> setHistoryDate(DateTime date) async {
    await _fetchHistory(date);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final storeOrdersProvider = StateNotifierProvider.family<StoreOrdersNotifier,
    StoreOrdersState, String>(
  (ref, storeId) => StoreOrdersNotifier(storeId),
);

final _myStoresListProvider =
    FutureProvider<List<_SimpleStore>>((ref) async {
  // Re-fetch khi user thay đổi (fix: tránh cache quán của user cũ sau khi đổi account)
  ref.watch(authProvider.select((s) => s.user?['_id']));
  final res = await DioClient.instance.get(ApiEndpoints.myStores);
  final raw = res.data;
  final list =
      raw is List ? raw : (raw as Map<String, dynamic>)['stores'] as List? ?? [];
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    return _SimpleStore(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      name: m['name'] as String? ?? '',
    );
  }).toList();
});

// ─── Screen ────────────────────────────────────────────────────────────────────

class StoreOrdersScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreOrdersScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreOrdersScreen> createState() =>
      _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends ConsumerState<StoreOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    SharedPreferences.getInstance()
        .then((p) => p.setString('last_store_id', widget.storeId));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    if (i == 0) {
      setState(() => _navIndex = 0);
      return;
    }
    setState(() => _navIndex = i);
    switch (i) {
      case 1:
        context.push('/store-dashboard/${widget.storeId}/menu');
        Future.delayed(Duration.zero, () => setState(() => _navIndex = 0));
        break;
      case 2:
        context.push('/store-dashboard/${widget.storeId}/reviews');
        Future.delayed(Duration.zero, () => setState(() => _navIndex = 0));
        break;
      case 3:
        context.push('/store-dashboard/${widget.storeId}/reports');
        Future.delayed(Duration.zero, () => setState(() => _navIndex = 0));
        break;
      case 4:
        context.push('/store-dashboard/${widget.storeId}/manage');
        Future.delayed(Duration.zero, () => setState(() => _navIndex = 0));
        break;
    }
  }

  // ─── App bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(StoreOrdersState state) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 8,
      title: _StoreSwitcher(
          storeId: widget.storeId, storeName: state.storeName),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Làm mới',
          onPressed: () =>
              ref.read(storeOrdersProvider(widget.storeId).notifier).refresh(),
        ),
        IconButton(
          icon: const Icon(Icons.switch_account_outlined),
          tooltip: 'Chuyển về khách hàng',
          onPressed: () => context.go('/home'),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt cửa hàng',
          onPressed: () =>
              context.push('/store-dashboard/${widget.storeId}/settings'),
        ),
      ],
    );
  }

  // ─── Emergency banner ─────────────────────────────────────────────────────

  Widget _buildBanner(StoreOrdersState state) {
    final closed = state.emergencyClosed || !state.isOpen;
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
                closed ? 'Mở cửa hàng?' : 'Đóng cửa khẩn cấp?'),
            content: Text(
              closed
                  ? 'Quán sẽ hiển thị và nhận đơn mới. Tiếp tục?'
                  : 'Quán sẽ ẩn khỏi danh sách và không nhận đơn mới. Tiếp tục?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Huỷ')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: closed ? Colors.green : Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: Text(closed ? 'Mở cửa' : 'Đóng khẩn cấp'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          // closed=true → muốn mở, closed=false → muốn đóng
          await ref
              .read(storeOrdersProvider(widget.storeId).notifier)
              .setStoreOpen(closed);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
          }
        }
      },
      child: Container(
        color: closed ? AppTheme.warning : AppTheme.success,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(
              closed ? 'Đang đóng cửa' : 'Đang mở cửa',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                closed ? 'Mở cửa trở lại' : 'Đóng khẩn cấp',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tab bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar(StoreOrdersState state) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppTheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: AppTheme.primary,
        tabs: [
          _BadgeTab(
              label: 'Chờ xử lý',
              count: state.pendingCount,
              badgeColor: Colors.red),
          _BadgeTab(
              label: 'Đang làm',
              count: state.inProgressCount,
              badgeColor: AppTheme.warning),
          const Tab(text: 'Lịch sử'),
        ],
      ),
    );
  }

  // ─── Bottom nav ───────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _navIndex,
      onTap: _onNavTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.restaurant_menu_outlined),
            activeIcon: Icon(Icons.restaurant_menu),
            label: 'Menu'),
        BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: 'Đánh giá'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Báo cáo'),
        BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_outlined),
            activeIcon: Icon(Icons.manage_accounts),
            label: 'Quản lý'),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeOrdersProvider(widget.storeId));

    if (state.isLoading && state.pendingOrders.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(state),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    if (state.error != null && state.pendingOrders.isEmpty) {
      final isAccessDenied = state.error!.contains('không có quyền');
      return Scaffold(
        appBar: _buildAppBar(state),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isAccessDenied
                    ? () => context.go('/store-dashboard')
                    : () => ref
                        .read(storeOrdersProvider(widget.storeId).notifier)
                        .refresh(),
                child: Text(isAccessDenied ? 'Quay lại' : 'Thử lại'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(state),
      body: Column(
        children: [
          _buildBanner(state),
          _buildTabBar(state),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PendingTab(
                    storeId: widget.storeId, state: state),
                _InProgressTab(
                    storeId: widget.storeId, state: state),
                _HistoryTab(
                    storeId: widget.storeId, state: state),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ─── Store switcher ───────────────────────────────────────────────────────────

class _StoreSwitcher extends ConsumerWidget {
  final String storeId;
  final String storeName;
  const _StoreSwitcher({required this.storeId, required this.storeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(_myStoresListProvider);
    final stores = storesAsync.valueOrNull ?? <_SimpleStore>[];
    final isLoading = storesAsync.isLoading;

    return PopupMenuButton<String>(
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      enabled: !isLoading,
      onSelected: (value) {
        if (value == '__create__') {
          context.push('/store/create');
        } else if (value != storeId) {
          context.pushReplacement('/store-dashboard/$value/orders');
        }
      },
      itemBuilder: (_) => [
        ...stores.map(
          (s) => PopupMenuItem<String>(
            value: s.id,
            height: 46,
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: s.id == storeId
                      ? const Color(0xFFF4B400)
                      : Colors.black45,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.name,
                    style: TextStyle(
                      fontWeight: s.id == storeId
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 14,
                      color: s.id == storeId
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF374151),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (s.id == storeId) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle,
                      size: 16, color: Color(0xFFF4B400)),
                ],
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: stores.length < 8 ? '__create__' : null,
          enabled: stores.length < 8,
          height: 46,
          child: Row(
            children: [
              Icon(
                stores.length < 8 ? Icons.add_circle_outline : Icons.block,
                size: 16,
                color: stores.length < 8 ? const Color(0xFF43A047) : Colors.grey,
              ),
              const SizedBox(width: 10),
              Text(
                stores.length < 8 ? 'Tạo cửa hàng mới' : 'Đã đạt giới hạn 8 cửa hàng',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: stores.length < 8 ? const Color(0xFF43A047) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 15, color: Colors.black54),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                storeName.isEmpty ? 'Cửa hàng' : storeName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              const Icon(Icons.arrow_drop_down,
                  size: 20, color: Colors.black54),
          ],
        ),
      ),
    );
  }
}

// ─── Badge tab ────────────────────────────────────────────────────────────────

class _BadgeTab extends StatelessWidget {
  final String label;
  final int count;
  final Color badgeColor;

  const _BadgeTab({
    required this.label,
    required this.count,
    this.badgeColor = Colors.blueGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Tab 1: Chờ xử lý ─────────────────────────────────────────────────────────

class _PendingTab extends ConsumerStatefulWidget {
  final String storeId;
  final StoreOrdersState state;
  const _PendingTab({required this.storeId, required this.state});

  @override
  ConsumerState<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends ConsumerState<_PendingTab> {
  // Rejection countdown: orderId → seconds remaining
  final _rejectCountdowns = <String, int>{};
  final _rejectTimers = <String, Timer>{};

  @override
  void dispose() {
    for (final t in _rejectTimers.values) {
      t.cancel();
    }
    super.dispose();
  }

  void _startReject(String orderId) {
    setState(() => _rejectCountdowns[orderId] = 10);
    _rejectTimers[orderId] =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final current = _rejectCountdowns[orderId] ?? 0;
      if (current <= 1) {
        t.cancel();
        _rejectTimers.remove(orderId);
        setState(() => _rejectCountdowns.remove(orderId));
        ref
            .read(storeOrdersProvider(widget.storeId).notifier)
            .rejectOrder(orderId, '');
      } else {
        setState(() => _rejectCountdowns[orderId] = current - 1);
      }
    });
  }

  void _cancelReject(String orderId) {
    _rejectTimers[orderId]?.cancel();
    _rejectTimers.remove(orderId);
    setState(() => _rejectCountdowns.remove(orderId));
  }

  void _openDetail(BuildContext context, StoreOrder order) {
    final notifier =
        ref.read(storeOrdersProvider(widget.storeId).notifier);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, ctrl) => StoreOrderDetailScreen(
          order: order,
          storeId: widget.storeId,
          onRecordPayment: order.paymentMethod != 'cod'
              ? (amount) async {
                  try {
                    await notifier.recordPayment(order.id, amount);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                    }
                  }
                }
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.state.pendingOrders;
    final s = widget.state;
    final notifier = ref.read(storeOrdersProvider(widget.storeId).notifier);

    if (orders.isEmpty) {
      return _EmptyTab(
          icon: Icons.inbox_outlined, label: 'Không có đơn chờ xử lý');
    }

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];
          final rc = _rejectCountdowns[order.id];
          return OrderCardStore(
            key: ValueKey(order.id),
            order: order,
            mode: OrderCardMode.pending,
            autoCancelMinutes: s.autoCancelMinutes,
            autoConfirmMinutes: s.autoConfirmMinutes,
            deliveryTimeoutMinutes: s.deliveryTimeoutMinutes,
            rejectCountdown: rc,
            onTap: () => _openDetail(context, order),
            onAccept: () async {
              try {
                await notifier.acceptOrder(order.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                }
              }
            },
            onRejectStart: () => _startReject(order.id),
            onRejectCancel: () => _cancelReject(order.id),
            onRecordPayment: order.paymentMethod != 'cod'
                ? (amount) async {
                    try {
                      await notifier.recordPayment(order.id, amount);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')));
                      }
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}

// ─── Tab 2: Đang làm ──────────────────────────────────────────────────────────

class _InProgressTab extends ConsumerWidget {
  final String storeId;
  final StoreOrdersState state;
  const _InProgressTab({required this.storeId, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = state.inProgressOrders;
    final notifier = ref.read(storeOrdersProvider(storeId).notifier);

    if (orders.isEmpty) {
      return _EmptyTab(
          icon: Icons.restaurant_outlined,
          label: 'Không có đơn đang làm');
    }

    return RefreshIndicator(
      onRefresh: notifier.fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: orders.length,
        itemBuilder: (context, i) {
          final order = orders[i];
          VoidCallback? deliverCb;
          if (order.mainStatus == 'preparing') {
            deliverCb = () async {
              try {
                await notifier.startDelivery(order.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
                }
              }
            };
          } else if (order.mainStatus == 'delivering') {
            deliverCb = () async {
              try {
                await notifier.markDelivered(order.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
                }
              }
            };
          }
          // delivered: không có nút action (chờ khách xác nhận)

          return OrderCardStore(
            key: ValueKey(order.id),
            order: order,
            mode: OrderCardMode.active,
            autoCancelMinutes: state.autoCancelMinutes,
            autoConfirmMinutes: state.autoConfirmMinutes,
            deliveryTimeoutMinutes: state.deliveryTimeoutMinutes,
            onTap: () => _openDetail(context, ref, order, notifier),
            onDeliver: deliverCb,
            onReturnToPending: order.mainStatus != 'delivered'
                ? () async {
                    try {
                      await notifier.returnToPending(order.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
                      }
                    }
                  }
                : null,
            onRecordPayment: order.paymentMethod != 'cod'
                ? (amount) async {
                    try {
                      await notifier.recordPayment(order.id, amount);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(_extractDioError(e))));
                      }
                    }
                  }
                : null,
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, StoreOrder order,
      StoreOrdersNotifier notifier) {
    VoidCallback? deliverCb;
    if (order.mainStatus == 'preparing') {
      deliverCb = () async {
        try {
          await notifier.startDelivery(order.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
          }
        }
      };
    } else if (order.mainStatus == 'delivering') {
      deliverCb = () async {
        try {
          await notifier.markDelivered(order.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
          }
        }
      };
    }
    // delivered: không có nút action

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, __) => StoreOrderDetailScreen(
          order: order,
          storeId: storeId,
          onDeliver: deliverCb,
          onReturnToPending: order.mainStatus != 'delivered'
              ? () async {
                  try {
                    await notifier.returnToPending(order.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(_extractDioError(e))));
                    }
                  }
                }
              : null,
          onRecordPayment: order.paymentMethod != 'cod'
              ? (amount) async {
                  try {
                    await notifier.recordPayment(order.id, amount);
                  } catch (_) {}
                }
              : null,
        ),
      ),
    );
  }
}

// ─── Tab 3: Lịch sử ──────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  final String storeId;
  final StoreOrdersState state;
  const _HistoryTab({required this.storeId, required this.state});

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final orders = s.filteredHistory;
    final notifier =
        ref.read(storeOrdersProvider(widget.storeId).notifier);
    final total = s.historyCompleted + s.historyCancelled;

    return Column(
      children: [
        // Stats row
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _pickDate(context, s, notifier),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_dateLabel(s.historyDate)} $total (hoàn thành ${s.historyCompleted}, hủy ${s.historyCancelled})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Doanh thu ${_fmtRevenue(s.historyRevenue)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                  label: 'Tất cả',
                  active: s.historyFilter == 'all',
                  onTap: () => notifier.setHistoryFilter('all')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Hoàn thành',
                  active: s.historyFilter == 'completed',
                  onTap: () => notifier.setHistoryFilter('completed')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Đã hủy',
                  active: s.historyFilter == 'cancelled',
                  onTap: () => notifier.setHistoryFilter('cancelled')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Kiểm tra thu tiền',
                  active: s.historyFilter == 'check_payment',
                  onTap: () =>
                      notifier.setHistoryFilter('check_payment')),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: notifier.setHistorySearch,
            decoration: InputDecoration(
              hintText: 'Tìm mã đơn...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: s.historySearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        notifier.setHistorySearch('');
                      })
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
          ),
        ),

        // List
        Expanded(
          child: orders.isEmpty
              ? _EmptyTab(
                  icon: Icons.history,
                  label: 'Không có đơn nào')
              : RefreshIndicator(
                  onRefresh: () async {
                    await notifier.refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: orders.length,
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      return OrderCardStore(
                        key: ValueKey(order.id),
                        order: order,
                        mode: OrderCardMode.history,
                        onTap: () => _openDetail(context, order),
                        onRecordPayment: order.remainingAmount > 0
                            ? (amount) async {
                                try {
                                  await notifier.recordPayment(order.id, amount);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Lỗi: $e')));
                                  }
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, StoreOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        builder: (_, __) => StoreOrderDetailScreen(
          order: order,
          storeId: widget.storeId,
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    StoreOrdersState s,
    StoreOrdersNotifier notifier,
  ) async {
    final now = DateTime.now();
    final initial = s.historyDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now,
      helpText: 'Chọn ngày xem thống kê',
    );
    if (picked != null) {
      await notifier.setHistoryDate(picked);
    }
  }

  bool _isToday(DateTime? d) {
    if (d == null) return true;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _dateLabel(DateTime? d) {
    if (_isToday(d)) return 'Hôm nay';
    return '${d!.day}/${d.month}/${d.year}';
  }

  String _fmtRevenue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return '${v.toStringAsFixed(0)}đ';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? AppTheme.primary
                  : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                active ? FontWeight.w600 : FontWeight.normal,
            color: active ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );
  }
}
