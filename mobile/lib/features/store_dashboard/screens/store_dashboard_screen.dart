// lib/features/store_dashboard/screens/store_dashboard_screen.dart
// Tạo theo spec v3.1 — mục 5.3 (store_owner), 7 (order flow), 9 (notifications)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/order.dart';
import '../../../core/models/store.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ----------
// Providers
// ----------

/// Danh sách quán mà user đang sở hữu (UA-6: 1 user nhiều quán)
final myStoresProvider = FutureProvider.autoDispose<List<Store>>((ref) async {
  final client = ref.watch(dioClientProvider);
  final res = await client.dio.get(ApiEndpoints.myStores);
  final raw = res.data;
  final list = raw is List
      ? List<Map<String, dynamic>>.from(raw)
      : List<Map<String, dynamic>>.from(raw['stores'] ?? []);
  return list.map(Store.fromJson).toList();
});

/// ID quán đang được chọn trong session
final selectedStoreIdProvider = StateProvider<String?>((ref) => null);

/// Orders theo tab — spec 5.3.3: 5 tab
final storeOrdersProvider =
    FutureProvider.autoDispose.family<List<Order>, _OrderQuery>((ref, q) async {
  final storeId = ref.watch(selectedStoreIdProvider);
  if (storeId == null) return [];
  final client = ref.watch(dioClientProvider);
  final res = await client.dio.get(
    ApiEndpoints.storeOrders(storeId),
    queryParameters: {
      'mainStatus': q.mainStatus,
      if (q.paymentStatus != null) 'paymentStatus': q.paymentStatus,
    },
  );
  final raw = res.data;
  final list = raw is List
      ? List<Map<String, dynamic>>.from(raw)
      : List<Map<String, dynamic>>.from(raw['orders'] ?? []);
  return list.map(Order.fromJson).toList();
});

class _OrderQuery {
  final String mainStatus;
  final String? paymentStatus;
  const _OrderQuery(this.mainStatus, [this.paymentStatus]);

  @override
  bool operator ==(Object other) =>
      other is _OrderQuery &&
      other.mainStatus == mainStatus &&
      other.paymentStatus == paymentStatus;

  @override
  int get hashCode => Object.hash(mainStatus, paymentStatus);
}

// -------
// Screen
// -------

class StoreDashboardScreen extends ConsumerStatefulWidget {
  const StoreDashboardScreen({super.key});

  @override
  ConsumerState<StoreDashboardScreen> createState() =>
      _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends ConsumerState<StoreDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ProviderSubscription<AsyncValue<List<Store>>>? _storesSub;

  // spec 5.3.3 — 5 tab đơn hàng
  static const _tabs = [
    _TabDef(label: 'Đơn mới',      icon: Icons.inbox_outlined,          mainStatus: 'pending_store'),
    _TabDef(label: 'Chuẩn bị',     icon: Icons.restaurant_outlined,     mainStatus: 'preparing'),
    _TabDef(label: 'Đang giao',    icon: Icons.delivery_dining_outlined, mainStatus: 'delivering'),
    _TabDef(label: 'Hoàn thành',   icon: Icons.check_circle_outline,    mainStatus: 'completed'),
    _TabDef(label: 'Còn thu tiền', icon: Icons.payments_outlined,       mainStatus: 'delivered',
            paymentStatus: 'partial,cod_pending'), // filter OR — xử lý backend
  ];

  @override
  
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _storesSub = ref.listenManual(myStoresProvider, (_, next) {
      next.whenData((stores) {
        if (stores.isEmpty) return;
        final current = ref.read(selectedStoreIdProvider);
        if (current == null || !stores.any((s) => s.id == current)) {
          ref.read(selectedStoreIdProvider.notifier).state = stores.first.id;
        }
      });
    }, fireImmediately: true);

  @override
  void dispose() {
    _storesSub?.close();
    _tabController.dispose();
    super.dispose();
  }

  }

  // -------
  // Build
  // -------

  @override
  Widget build(BuildContext context) {
    final myStoresAsync = ref.watch(myStoresProvider);
    final selectedId = ref.watch(selectedStoreIdProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return myStoresAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Không tải được danh sách quán: $err')),
      ),
      data: (stores) {
        // Nếu user chưa có quán nào → hướng dẫn tạo
        if (stores.isEmpty) {
          return _NoStoreView(onCreateTap: () => context.push('/store/create'));
        }

        // Đảm bảo selectedId hợp lệ; nếu chưa chọn thì chọn quán đầu
        final effectiveId = (selectedId != null &&
                stores.any((s) => s.id == selectedId))
            ? selectedId
            : stores.first.id;



        final store = stores.firstWhere((s) => s.id == effectiveId);

        return Scaffold(
  appBar: _buildAppBar(context, stores, store, auth, theme),
    body: Column(
    children: [
      _StoreStatusBanner(store: store, storeId: effectiveId),
      TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: _tabs
            .map((t) => Tab(
                  icon: Icon(t.icon, size: 18),
                  text: t.label,
                ))
            .toList(),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: _tabs
              .map((t) => _OrderTabView(
                    storeId: effectiveId,
                    tabDef: t,
                  ))
              .toList(),
        ),
      ),
    ],
  ),
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () => context.push('/store-dashboard/$effectiveId/menu'),
    icon: const Icon(Icons.restaurant_menu),
    label: const Text('Menu'),
  ),
  bottomNavigationBar: _StoreDashboardBottomNav(storeId: effectiveId),
);
      },
    );
  }

Future<void> _deleteStore(BuildContext context, Store store) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa quán?'),
        content: Text('Bạn có chắc muốn xóa quán "${store.name}"? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final dio = ref.read(dioClientProvider);
      await dio.dio.delete(ApiEndpoints.deleteStore(store.id), data: {});
      ref.read(selectedStoreIdProvider.notifier).state = null;
      ref.invalidate(myStoresProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------
  // AppBar — chọn quán nếu có nhiều quán (UA-6)
  // ------



  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    List<Store> stores,
    Store current,
    dynamic auth,
    ThemeData theme,
  ) {
    return AppBar(
      title: stores.length == 1
          ? Text(current.name, overflow: TextOverflow.ellipsis)
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current.id,
                icon: const Icon(Icons.arrow_drop_down),
                items: stores
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15)),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    ref.read(selectedStoreIdProvider.notifier).state = id;
                    // Invalidate để reload orders cho quán mới
                    ref.invalidate(storeOrdersProvider);
                  }
                },
              ),
            ),
      actions: [
        // Chuyển về vai trò khách hàng (UA-1)
        PopupMenuButton<String>(
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Chuyển vai trò',
          onSelected: (role) {
            ref.read(authProvider.notifier).switchRole(role);
            if (role == 'customer') context.go('/home');
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'customer', child: Text('Vai trò: Khách hàng')),
          ],
        ),
        // Tạo quán mới
        
IconButton(
          icon: const Icon(Icons.add_business_outlined),
          tooltip: 'Tạo quán mới',
          onPressed: () => context.push('/store/create'),
        ),
        // Cài đặt quán
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Cài đặt quán',
          onPressed: () =>
              context.push('/store/${current.id}/settings'),
        ),
        // Xóa quán hiện tại
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Xóa quán này',
          onPressed: () => _deleteStore(context, current),
        ),

      ],
    );
  }
}

// -------
// Banner trạng thái + Emergency Closed (spec 5.3.5 + 0.8)
// -------

class _StoreStatusBanner extends ConsumerWidget {
  final Store store;
  final String storeId;
  const _StoreStatusBanner({required this.store, required this.storeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmergencyClosed = store.emergencyClosed;
    final isSuspended = store.isSuspended;
    final theme = Theme.of(context);

    Color bannerColor;
    String bannerText;
    IconData bannerIcon;

    if (isSuspended) {
      bannerColor = Colors.red.shade700;
      bannerText = 'Quán đang bị khoá bởi Admin';
      bannerIcon = Icons.lock_outline;
    } else if (isEmergencyClosed) {
      bannerColor = Colors.orange.shade700;
      bannerText = 'Đang đóng cửa khẩn cấp — Nhấn để mở lại';
      bannerIcon = Icons.warning_amber_outlined;
    } else {
      bannerColor = Colors.green.shade600;
      bannerText = 'Đang mở cửa';
      bannerIcon = Icons.storefront_outlined;
    }

    return InkWell(
      // Chỉ cho tap khi emergencyClosed & không bị suspended
      onTap: (!isSuspended && isEmergencyClosed)
          ? () => _toggleEmergency(context, ref, storeId, false)
          : null,
      child: Container(
        width: double.infinity,
        color: bannerColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(bannerIcon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(bannerText,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            // Toggle emergency close nếu đang mở
            if (!isSuspended && !isEmergencyClosed)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () =>
                    _toggleEmergency(context, ref, storeId, true),
                child: const Text('Đóng khẩn cấp'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleEmergency(
      BuildContext context, WidgetRef ref, String storeId, bool close) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(close ? 'Đóng cửa khẩn cấp?' : 'Mở lại cửa hàng?'),
        content: Text(close
            ? 'Quán sẽ ẩn khỏi feed và khách không đặt được. Đơn pre-order đang chờ sẽ bị giữ lại.'
            : 'Quán sẽ hiển thị trở lại. Đơn pre-order đang chờ sẽ được tự động release.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(close ? 'Đóng khẩn cấp' : 'Mở lại')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      final client = ref.read(dioClientProvider);
      await client.dio.patch(
        ApiEndpoints.storeEmergencyClose(storeId),
        data: {'emergencyClosed': close},
      );
      ref.invalidate(myStoresProvider);
      // spec OD-15: khi tắt emergencyClosed → backend trigger ngay job release pre-orders
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ---------
// Order Tab View — hiển thị danh sách đơn theo trạng thái
// ---------

class _OrderTabView extends ConsumerWidget {
  final String storeId;
  final _TabDef tabDef;

  const _OrderTabView({required this.storeId, required this.tabDef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = _OrderQuery(tabDef.mainStatus, tabDef.paymentStatus);
    final ordersAsync = ref.watch(storeOrdersProvider(query));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(storeOrdersProvider(query)),
      child: ordersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Không tải được đơn hàng',
                  style:
                      TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(storeOrdersProvider(query)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tabDef.icon, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Không có đơn nào',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _OrderCard(
              order: orders[i],
              storeId: storeId,
              tabDef: tabDef,
            ),
          );
        },
      ),
    );
  }
}

// ---------
// Order Card — hiển thị + actions theo trạng thái (spec 5.3.3, 7.3)
// ---------

class _OrderCard extends ConsumerWidget {
  final Order order;
  final String storeId;
  final _TabDef tabDef;

  const _OrderCard(
      {required this.order, required this.storeId, required this.tabDef});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // spec 8: in đậm 3 số cuối, mờ phần đầu
    final codeParts = order.code.split('-');
    final codePrefix = codeParts.length == 2 ? '${codeParts[0]}-' : '';
    final codeSuffix = codeParts.length == 2 ? codeParts[1] : order.code;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/store/$storeId/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: mã đơn + thời gian
              Row(
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: codePrefix,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),
                        TextSpan(
                          text: codeSuffix,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(order.createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Tên người nhận + SĐT (mask — spec 13)
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15,
                      color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(order.receiverName,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(_maskPhone(order.receiverPhone),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 4),
              // Cách giao (spec 6)
              Row(
                children: [
                  Icon(_deliveryIcon(order.deliveryMethod),
                      size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_deliveryLabel(order.deliveryMethod),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 8),
              // Items summary
              Text(
                order.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              // Total + payment status
              Row(
                children: [
                  Text(
                    _formatCurrency(order.totalAmount),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  _PaymentBadge(paymentStatus: order.paymentStatus),
                ],
              ),
              // "Còn phải thu" nếu partial (spec 5.3.4)
              if (order.remainingAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  'Còn phải thu: ${_formatCurrency(order.remainingAmount)}',
                  style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 12),
              // Action buttons theo tab
              _buildActions(context, ref, order, storeId, tabDef),
            ],
          ),
        ),
      ),
    );
  }

  // -------
  // Actions theo trạng thái (spec 5.3.3 + 7.3)
  // -------

  Widget _buildActions(BuildContext context, WidgetRef ref, Order order,
      String storeId, _TabDef tabDef) {
    switch (tabDef.mainStatus) {
      // Tab 1: Đơn mới — Nhận / Từ chối
      case 'pending_store':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Từ chối'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600),
                onPressed: () =>
                    _showRejectDialog(context, ref, order, storeId),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Nhận đơn'),
                onPressed: () =>
                    _updateStatus(context, ref, order, storeId, 'preparing'),
              ),
            ),
          ],
        );

      // Tab 2: Đang chuẩn bị — Bàn giao + nút "Tiền chưa vào TK" nếu CK
      case 'preparing':
        return Column(
          children: [
            Row(
              children: [
                // Cách A: bàn giao shipper → delivering
                if (order.deliveryMethod == DeliveryMethod.storeDelivery)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.delivery_dining, size: 16),
                      label: const Text('Bàn giao shipper'),
                      onPressed: () => _updateStatus(
                          context, ref, order, storeId, 'delivering'),
                    ),
                  ),
                // Cách B: khách đến lấy → delivered
                if (order.deliveryMethod == DeliveryMethod.selfPickup)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.store, size: 16),
                      label: const Text('Khách đã lấy'),
                      onPressed: () => _updateStatus(
                          context, ref, order, storeId, 'delivered'),
                    ),
                  ),
                // Cách C: shipper riêng → delivered
                if (order.deliveryMethod == DeliveryMethod.customerShipper)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.handshake_outlined, size: 16),
                      label: const Text('Đã bàn giao'),
                      onPressed: () => _updateStatus(
                          context, ref, order, storeId, 'delivered'),
                    ),
                  ),
              ],
            ),
            // "Tiền chưa vào TK" — chỉ khi CK trước (spec 5.3.3 tab 2 + OD-5)
            if (order.paymentStatus == OrderPaymentStatus.reportedPaid) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.money_off_outlined, size: 16),
                  label: const Text('Tiền chưa vào TK'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700),
                  onPressed: () =>
                      _markPaymentNotReceived(context, ref, order, storeId),
                ),
              ),
            ],
          ],
        );

      // Tab 3: Đang giao — "Đã giao"
      case 'delivering':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Đã giao hàng'),
            onPressed: () =>
                _updateStatus(context, ref, order, storeId, 'delivered'),
          ),
        );

      // Tab 4: Hoàn thành — chỉ xem (không có action)
      case 'completed':
        return const SizedBox.shrink();

      // Tab 5: Còn phải thu — "Đã nhận tiền" (spec 5.3.4)
      case 'delivered':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: const Text('Đã nhận tiền'),
            onPressed: () =>
                _showConfirmPaymentDialog(context, ref, order, storeId),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // --------
  // Dialogs & API calls
  // --------

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, Order order,
      String storeId, String newStatus) async {
    try {
      final client = ref.read(dioClientProvider);
      await client.dio.patch(
        ApiEndpoints.orderStatus(storeId, order.id),
        data: {'mainStatus': newStatus},
      );
      ref.invalidate(storeOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Từ chối đơn — bắt buộc nhập lý do (spec 5.3.3 tab 1)
  Future<void> _showRejectDialog(BuildContext context, WidgetRef ref,
      Order order, String storeId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Từ chối đơn hàng'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối *',
            hintText: 'Vd: Hết nguyên liệu, Đóng cửa sớm...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final client = ref.read(dioClientProvider);
      await client.dio.patch(
        ApiEndpoints.orderStatus(storeId, order.id),
        data: {
          'mainStatus': 'cancelled',
          'cancelInfo': {
            'by': 'store',
            'reason': reasonCtrl.text.trim(),
          },
        },
      );
      ref.invalidate(storeOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// "Tiền chưa vào TK" — đơn về awaiting_payment, push khách (spec OD-5)
  Future<void> _markPaymentNotReceived(BuildContext context, WidgetRef ref,
      Order order, String storeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tiền chưa vào tài khoản?'),
        content: const Text(
            'Đơn sẽ về trạng thái "Chờ thanh toán" và khách sẽ nhận thông báo cần chuyển lại. '
            'Nếu khách báo sai 3 lần sẽ bị admin cảnh báo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final client = ref.read(dioClientProvider);
      await client.dio.post(
        ApiEndpoints.orderPaymentNotReceived(storeId, order.id),
      );
      ref.invalidate(storeOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Xác nhận nhận tiền — nhập số tiền thực nhận (spec 5.3.4)
  Future<void> _showConfirmPaymentDialog(BuildContext context, WidgetRef ref,
      Order order, String storeId) async {
    final amountCtrl = TextEditingController(
      text: order.remainingAmount > 0
          ? order.remainingAmount.toStringAsFixed(0)
          : order.totalAmount.toStringAsFixed(0),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận đã nhận tiền'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Tổng đơn: ${_formatCurrency(order.totalAmount)}\n'
                'Đã nhận trước: ${_formatCurrency(order.paidAmount)}'),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Số tiền nhận lần này (₫)',
                border: OutlineInputBorder(),
                suffixText: '₫',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final amount =
        double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    try {
      final client = ref.read(dioClientProvider);
      await client.dio.post(
        ApiEndpoints.orderConfirmPayment(storeId, order.id),
        data: {'amount': amount},
      );
      ref.invalidate(storeOrdersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ------
  // Helpers
  // ------

  /// Mask SĐT: 09xx xxx 678 (spec 13)
  String _maskPhone(String phone) {
    if (phone.length < 10) return phone;
    return '${phone.substring(0, 4)} xxx ${phone.substring(phone.length - 3)}';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${dt.day}/${dt.month}';
  }

  String _formatCurrency(double amount) {
    // Đơn giản, không cần intl package trong skeleton này
    final s = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return '$buffer₫';
  }

  IconData _deliveryIcon(DeliveryMethod method) {
  switch (method) {
    case DeliveryMethod.storeDelivery:
      return Icons.delivery_dining;
    case DeliveryMethod.selfPickup:
      return Icons.store;
    case DeliveryMethod.customerShipper:
      return Icons.directions_bike;
  }
}

  String _deliveryLabel(DeliveryMethod method) {
  switch (method) {
    case DeliveryMethod.storeDelivery:
      return 'Quán giao';
    case DeliveryMethod.selfPickup:
      return 'Tự đến lấy';
    case DeliveryMethod.customerShipper:
      return 'Shipper riêng';
  }
}
}

// -------
// Payment Badge
// -------


class _PaymentBadge extends StatelessWidget {
  final OrderPaymentStatus paymentStatus;
  const _PaymentBadge({required this.paymentStatus});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (paymentStatus) {
      OrderPaymentStatus.unpaid        => ('Chưa trả',     Colors.grey),
      OrderPaymentStatus.reportedPaid  => ('Đã báo CK',    Colors.blue.shade600),
      OrderPaymentStatus.partial       => ('Trả một phần', Colors.orange.shade700),
      OrderPaymentStatus.paidFull      => ('Đã trả đủ',    Colors.green.shade600),
      OrderPaymentStatus.codPending    => ('COD chờ thu',  Colors.orange.shade700),
      OrderPaymentStatus.codCollected  => ('COD đã thu',   Colors.green.shade600),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ------
// Bottom Navigation
// ------

class _StoreDashboardBottomNav extends StatelessWidget {
  final String storeId;
  const _StoreDashboardBottomNav({required this.storeId});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (i) {
        switch (i) {
          case 0:
            context.go('/store-dashboard');
          case 1:
            context.push('/store-dashboard/$storeId/menu');
          case 2:
            context.push('/store/$storeId/reviews');
          case 3:
            context.push('/store/$storeId/settings');
        }
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard'),
        NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu'),
        NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'Đánh giá'),
        NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt'),
      ],
    );
  }
}

// --------
// No Store View
// -------

class _NoStoreView extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _NoStoreView({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Quay lại',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Về trang chủ',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.storefront_outlined,
                  size: 72, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Bạn chưa có cửa hàng nào',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Tạo quán đầu tiên để bắt đầu nhận đơn hàng.',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add_business),
                label: const Text('Tạo cửa hàng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------
// Data classes (internal)
// -------

class _TabDef {
  final String label;
  final IconData icon;
  final String mainStatus;
  final String? paymentStatus; // filter thêm nếu cần
  const _TabDef({
    required this.label,
    required this.icon,
    required this.mainStatus,
    this.paymentStatus,
  });
}

// -------
// lib/features/store_dashboard/screens/store_dashboard_screen.dart