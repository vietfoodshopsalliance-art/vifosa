// lib/features/order/screens/orders_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/order_code_text.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

final ordersListProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, tab) async {
  final res = await DioClient.instance.get(
    ApiEndpoints.myOrders,
    queryParameters: {'tab': tab},
  );
  return List<Map<String, dynamic>>.from(res.data['orders'] ?? res.data);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F2E8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          shadowColor: Colors.black12,
          surfaceTintColor: Colors.transparent,
          foregroundColor: Colors.black87,
          leading: IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/home'),
          ),
          title: const Text(
            'Đơn hàng của tôi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFFF4B400),
            unselectedLabelColor: Colors.black54,
            indicatorColor: Color(0xFFF4B400),
            indicatorWeight: 2.5,
            tabs: [
              Tab(text: 'Chờ xử lý'),
              Tab(text: 'Đang làm'),
              Tab(text: 'Lịch sử'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OrdersTab(tab: 'pending'),
            _OrdersTab(tab: 'active'),
            _OrdersTab(tab: 'history'),
          ],
        ),
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  final String tab;
  const _OrdersTab({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersListProvider(tab));

    return RefreshIndicator(
      color: const Color(0xFFF4B400),
      onRefresh: () async => ref.invalidate(ordersListProvider(tab)),
      child: ordersAsync.when(
        data: (orders) => orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black26),
                        SizedBox(height: 12),
                        Text('Không có đơn hàng',
                            style: TextStyle(color: Colors.black45, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _OrderCard(order: orders[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF4B400))),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.black26),
              const SizedBox(height: 12),
              const Text('Không thể tải đơn hàng',
                  style: TextStyle(color: Colors.black45)),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4B400),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => ref.invalidate(ordersListProvider(tab)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order['mainStatus'] as String? ?? '';
    final storeRaw = order['storeId'];
    final storeName = storeRaw is Map ? (storeRaw['name'] as String? ?? '') : '';
    final createdAt = order['createdAt'] != null
        ? _dateFormat.format(DateTime.parse(order['createdAt']).toLocal())
        : '';

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/order/${order['_id']}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OrderCodeText(code: order['code'] as String? ?? ''),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              if (storeName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(storeName, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
              const SizedBox(height: 4),
              Text(createdAt, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(order['items'] as List?)?.length ?? 0} món',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    _vnd.format(order['totalAmount'] ?? 0),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF4B400),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  static const _labels = <String, (String, Color)>{
    'pending_store':       ('Chờ xác nhận',   Color(0xFFFFC107)),
    'awaiting_payment':    ('Chờ thanh toán', Color(0xFFFF9800)),
    'awaiting_store_open': ('Chờ quán mở',    Color(0xFFFFC107)),
    'preparing':           ('Đang chuẩn bị',  Color(0xFF2196F3)),
    'delivering':          ('Đang giao',       Color(0xFF9C27B0)),
    'delivered':           ('Đã giao',         Color(0xFF4CAF50)),
    'completed':           ('Đã nhận',         Color(0xFF4CAF50)),
    'cancelled':           ('Đã hủy',          Color(0xFFF44336)),
  };

  @override
  Widget build(BuildContext context) {
    final info = _labels[status] ?? (status, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: info.$2.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: info.$2),
      ),
      child: Text(
        info.$1,
        style: TextStyle(color: info.$2, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
