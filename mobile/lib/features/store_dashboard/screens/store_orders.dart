// lib/features/store_dashboard/screens/store_orders.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/widgets/order_code_text.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/theme/theme.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class StoreOrderModel {
  final String id;
  final String code;
  final String status;
  final String paymentMethod; // cod | bank_transfer
  final String paymentStatus;
  final double total;
  final String customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final List<OrderItemModel> items;
  final DateTime createdAt;

  const StoreOrderModel({
    required this.id,
    required this.code,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    required this.items,
    required this.createdAt,
  });

  factory StoreOrderModel.fromJson(Map<String, dynamic> j) => StoreOrderModel(
        id: j['_id'] ?? '',
        code: j['code'] ?? '',
        status: j['status'] ?? 'pending',
        paymentMethod: j['paymentMethod'] ?? 'cod',
        paymentStatus: j['paymentStatus'] ?? 'pending',
        total: (j['total'] ?? 0).toDouble(),
        customerName: j['customer']?['nickname'] ?? 'Khách hàng',
        customerPhone: j['customer']?['phone'],
        deliveryAddress: j['deliveryAddress']?['full'],
        items: (j['items'] as List? ?? [])
            .map((e) => OrderItemModel.fromJson(e))
            .toList(),
        createdAt:
            DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class OrderItemModel {
  final String name;
  final int quantity;
  final double price;

  const OrderItemModel({
    required this.name,
    required this.quantity,
    required this.price,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> j) => OrderItemModel(
        name: j['item']?['name'] ?? j['name'] ?? '',
        quantity: j['quantity'] ?? 1,
        price: (j['price'] ?? 0).toDouble(),
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

const _tabs = [
  'pending',
  'accepted',
  'delivering',
  'delivered',
  'cancelled',
];

const _tabLabels = [
  'Mới',
  'Đã nhận',
  'Đang giao',
  'Hoàn thành',
  'Đã huỷ',
];

final storeOrdersProvider = StateNotifierProvider.family<StoreOrdersNotifier,
    StoreOrdersState, String>(
  (ref, storeId) => StoreOrdersNotifier(storeId),
);

class StoreOrdersState {
  final Map<String, List<StoreOrderModel>> ordersByStatus;
  final bool isLoading;
  final String? error;
  final Set<String> processingIds;

  const StoreOrdersState({
    this.ordersByStatus = const {},
    this.isLoading = false,
    this.error,
    this.processingIds = const {},
  });

  StoreOrdersState copyWith({
    Map<String, List<StoreOrderModel>>? ordersByStatus,
    bool? isLoading,
    String? error,
    Set<String>? processingIds,
  }) =>
      StoreOrdersState(
        ordersByStatus: ordersByStatus ?? this.ordersByStatus,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        processingIds: processingIds ?? this.processingIds,
      );

  List<StoreOrderModel> forStatus(String status) =>
      ordersByStatus[status] ?? [];
}

class StoreOrdersNotifier extends StateNotifier<StoreOrdersState> {
  final String storeId;

  StoreOrdersNotifier(this.storeId) : super(const StoreOrdersState()) {
    _load();
    _subscribeSocket();
  }

  void _subscribeSocket() {
    SocketClient().joinStore(storeId);
    SocketClient().on('new_order', (_) => _load());
    SocketClient().on('order_status_changed', (_) => _load());
  }

  @override
  void dispose() {
    SocketClient().off('new_order');
    SocketClient().off('order_status_changed');
    super.dispose();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await DioClient().dio.get(ApiEndpoints.storeOrders(storeId));
      final data = res.data as Map<String, dynamic>;
      final allOrders = (data['orders'] as List? ?? [])
          .map((e) => StoreOrderModel.fromJson(e))
          .toList();

      final grouped = <String, List<StoreOrderModel>>{};
      for (final status in _tabs) {
        grouped[status] =
            allOrders.where((o) => o.status == status).toList();
      }
      state = state.copyWith(
          ordersByStatus: grouped, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<void> _runAction(String orderId, Future<void> Function() action) async {
    final ids = {...state.processingIds, orderId};
    state = state.copyWith(processingIds: ids);
    try {
      await action();
      await _load();
    } catch (_) {
    } finally {
      final updated = {...state.processingIds}..remove(orderId);
      state = state.copyWith(processingIds: updated);
    }
  }

  Future<void> accept(String orderId) => _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.acceptOrder(storeId, orderId));
      });

  Future<void> reject(String orderId) => _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.rejectOrder(storeId, orderId));
      });

  Future<void> markDelivering(String orderId) =>
      _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.markDelivering(storeId, orderId));
      });

  Future<void> markDelivered(String orderId) =>
      _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.markDelivered(storeId, orderId));
      });

  Future<void> confirmMoney(String orderId) =>
      _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.confirmMoney(storeId, orderId));
      });

  Future<void> moneyNotReceived(String orderId) =>
      _runAction(orderId, () async {
        await DioClient()
            .dio
            .post(ApiEndpoints.moneyNotReceived(storeId, orderId));
      });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StoreOrdersScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreOrdersScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends ConsumerState<StoreOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(storeOrdersProvider(widget.storeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý đơn hàng'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: List.generate(
            _tabs.length,
            (i) {
              final count = state.forStatus(_tabs[i]).length;
              return Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_tabLabels[i]),
                    if (count > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _tabs[i] == 'pending'
                              ? Colors.red
                              : AppTheme.primary,
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
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(storeOrdersProvider(widget.storeId).notifier).refresh(),
          ),
        ],
      ),
      body: state.isLoading && state.ordersByStatus.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(state.error!))
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(
                    _tabs.length,
                    (i) => _OrderTab(
                      status: _tabs[i],
                      orders: state.forStatus(_tabs[i]),
                      processingIds: state.processingIds,
                      storeId: widget.storeId,
                    ),
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order Tab
// ---------------------------------------------------------------------------

class _OrderTab extends ConsumerWidget {
  final String status;
  final List<StoreOrderModel> orders;
  final Set<String> processingIds;
  final String storeId;

  const _OrderTab({
    required this.status,
    required this.orders,
    required this.processingIds,
    required this.storeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return const Center(
        child: Text(
          'Không có đơn nào',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(storeOrdersProvider(storeId).notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, i) => _StoreOrderCard(
          order: orders[i],
          isProcessing: processingIds.contains(orders[i].id),
          onAccept: status == 'pending'
              ? () => ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .accept(orders[i].id)
              : null,
          onReject: status == 'pending'
              ? () => _confirmReject(context, ref, orders[i].id)
              : null,
          onMarkDelivering: status == 'accepted'
              ? () => ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .markDelivering(orders[i].id)
              : null,
          onMarkDelivered: status == 'delivering'
              ? () => ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .markDelivered(orders[i].id)
              : null,
          onConfirmMoney: status == 'delivered' &&
                  orders[i].paymentMethod == 'cod' &&
                  orders[i].paymentStatus == 'pending'
              ? () => ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .confirmMoney(orders[i].id)
              : null,
          onMoneyNotReceived: status == 'delivered' &&
                  orders[i].paymentMethod == 'cod' &&
                  orders[i].paymentStatus == 'pending'
              ? () => ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .moneyNotReceived(orders[i].id)
              : null,
        ),
      ),
    );
  }

  void _confirmReject(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối đơn hàng?'),
        content: const Text(
            'Hành động này không thể hoàn tác. Đơn sẽ bị huỷ.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(storeOrdersProvider(storeId).notifier)
                  .reject(orderId);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Store Order Card
// ---------------------------------------------------------------------------

class _StoreOrderCard extends StatelessWidget {
  final StoreOrderModel order;
  final bool isProcessing;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onMarkDelivering;
  final VoidCallback? onMarkDelivered;
  final VoidCallback? onConfirmMoney;
  final VoidCallback? onMoneyNotReceived;

  const _StoreOrderCard({
    required this.order,
    required this.isProcessing,
    this.onAccept,
    this.onReject,
    this.onMarkDelivering,
    this.onMarkDelivered,
    this.onConfirmMoney,
    this.onMoneyNotReceived,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                OrderCodeText(code: order.code),
                const Spacer(),
                Text(
                  DateFormat('HH:mm dd/MM').format(order.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Customer info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(order.customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (order.customerPhone != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.phone_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(order.customerPhone!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ],
            ),

            if (order.deliveryAddress != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress!,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Items
            ...order.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.name)),
                    Text(
                      _fmtCurrency(item.price * item.quantity),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Total + payment
            Row(
              children: [
                Text(
                  'Tổng: ${_fmtCurrency(order.total)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.paymentMethod == 'cod' ? 'COD' : 'Chuyển khoản',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            // Action buttons
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else ...[
              if (onAccept != null || onReject != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onReject != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red)),
                          child: const Text('Từ chối'),
                        ),
                      ),
                    if (onReject != null && onAccept != null)
                      const SizedBox(width: 8),
                    if (onAccept != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success),
                          child: const Text('Nhận đơn'),
                        ),
                      ),
                  ],
                ),
              ],
              if (onMarkDelivering != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onMarkDelivering,
                    icon: const Icon(Icons.delivery_dining),
                    label: const Text('Bắt đầu giao hàng'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary),
                  ),
                ),
              ],
              if (onMarkDelivered != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onMarkDelivered,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Xác nhận đã giao'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success),
                  ),
                ),
              ],
              if (onConfirmMoney != null || onMoneyNotReceived != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onMoneyNotReceived != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onMoneyNotReceived,
                          style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange)),
                          child: const Text('Chưa nhận tiền'),
                        ),
                      ),
                    if (onMoneyNotReceived != null && onConfirmMoney != null)
                      const SizedBox(width: 8),
                    if (onConfirmMoney != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onConfirmMoney,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.success),
                          child: const Text('Đã nhận tiền'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _fmtCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)}đ';
  }
}
