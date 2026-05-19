// lib/features/store_dashboard/orders/store_orders_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/store_order.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class StoreOrdersState {
  final List<StoreOrder> pendingOrders;       // tab: new
  final List<StoreOrder> preparingOrders;     // tab: preparing
  final List<StoreOrder> deliveringOrders;    // tab: delivering
  final List<StoreOrder> deliveredPaidOrders; // tab: delivered_paid
  final List<StoreOrder> deliveredUnpaidOrders; // tab: delivered_unpaid

  const StoreOrdersState({
    this.pendingOrders = const [],
    this.preparingOrders = const [],
    this.deliveringOrders = const [],
    this.deliveredPaidOrders = const [],
    this.deliveredUnpaidOrders = const [],
  });

  /// Gộp delivered_unpaid + delivered_paid để màn hình dùng nếu cần
  List<StoreOrder> get needsCollectionOrders => deliveredUnpaidOrders;

  StoreOrdersState copyWith({
    List<StoreOrder>? pendingOrders,
    List<StoreOrder>? preparingOrders,
    List<StoreOrder>? deliveringOrders,
    List<StoreOrder>? deliveredPaidOrders,
    List<StoreOrder>? deliveredUnpaidOrders,
  }) =>
      StoreOrdersState(
        pendingOrders: pendingOrders ?? this.pendingOrders,
        preparingOrders: preparingOrders ?? this.preparingOrders,
        deliveringOrders: deliveringOrders ?? this.deliveringOrders,
        deliveredPaidOrders: deliveredPaidOrders ?? this.deliveredPaidOrders,
        deliveredUnpaidOrders:
            deliveredUnpaidOrders ?? this.deliveredUnpaidOrders,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class StoreOrdersNotifier
    extends StateNotifier<AsyncValue<StoreOrdersState>> {
  final String storeId;
  final Ref _ref;

  StoreOrdersNotifier(this.storeId, this._ref)
      : super(const AsyncValue.loading()) {
    fetchOrders();
  }

  /// Fetch tất cả 5 tab song song
  Future<void> fetchOrders() async {
    state = const AsyncValue.loading();
    try {
      final dio = _ref.read(dioClientProvider);

      final results = await Future.wait([
        _fetchTab(dio, 'new'),
        _fetchTab(dio, 'preparing'),
        _fetchTab(dio, 'delivering'),
        _fetchTab(dio, 'delivered_paid'),
        _fetchTab(dio, 'delivered_unpaid'),
      ]);

      state = AsyncValue.data(StoreOrdersState(
        pendingOrders: results[0]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        preparingOrders: results[1],
        deliveringOrders: results[2],
        deliveredPaidOrders: results[3],
        deliveredUnpaidOrders: results[4],
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<List<StoreOrder>> _fetchTab(dynamic dio, String tab) async {
    final res = await dio.get(
      ApiEndpoints.storeOrders(storeId),
      queryParameters: {'tab': tab},
    );
    final data = res.data is Map ? res.data['orders'] : res.data;
    return (data as List)
        .map((e) => StoreOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  Future<void> acceptOrder(String orderId) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(ApiEndpoints.orderAccept(storeId, orderId));
    await fetchOrders();
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(
      ApiEndpoints.orderReject(storeId, orderId),
      data: {'reason': reason},
    );
    await fetchOrders();
  }

  Future<void> markDelivering(String orderId) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(ApiEndpoints.orderMarkDelivering(storeId, orderId));
    await fetchOrders();
  }

  Future<void> markDelivered(String orderId) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(ApiEndpoints.orderMarkDelivered(storeId, orderId));
    await fetchOrders();
  }

  Future<void> confirmMoneyReceived(String orderId, double amount) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(
      ApiEndpoints.orderConfirmMoney(storeId, orderId),
      data: {'amount': amount},
    );
    await fetchOrders();
  }

  Future<void> reportMoneyNotReceived(String orderId) async {
    final dio = _ref.read(dioClientProvider);
    await dio.post(ApiEndpoints.orderMoneyNotReceived(storeId, orderId));
    await fetchOrders();
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final storeOrdersProvider = StateNotifierProvider.family<StoreOrdersNotifier,
    AsyncValue<StoreOrdersState>, String>(
  (ref, storeId) => StoreOrdersNotifier(storeId, ref),
);
// lib/features/store_dashboard/orders/store_orders_provider.dart