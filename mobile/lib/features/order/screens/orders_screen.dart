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

final ordersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await DioClient().dio.get(ApiEndpoints.orders);
  return List<Map<String, dynamic>>.from(res.data['orders'] ?? res.data);
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersListProvider);

    return Scaffold(
      appBar: AppBar(
  leading: IconButton(
    icon: const Icon(Icons.home_outlined),
    onPressed: () => context.go('/home'),
  ),
  title: const Text('Đơn hàng của tôi'),
),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ordersListProvider),
        child: ordersAsync.when(
          data: (orders) => orders.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Bạn chưa có đơn hàng nào', style: TextStyle(color: Colors.grey)),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Không thể tải đơn hàng'),
                TextButton(
                  onPressed: () => ref.invalidate(ordersListProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    final status = order['status'] ?? '';
    final createdAt = order['createdAt'] != null
        ? _dateFormat.format(DateTime.parse(order['createdAt']).toLocal())
        : '';

    return Card(
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
                    child: OrderCodeText(code: order['orderCode'] ?? ''),
                  ),
                  _StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                order['storeName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
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

  static const _labels = {
    'pending': ('Chờ xác nhận', Color(0xFFFFC107)),
    'accepted': ('Đã xác nhận', Color(0xFF2196F3)),
    'delivering': ('Đang giao', Color(0xFF9C27B0)),
    'delivered': ('Đã giao', Color(0xFF4CAF50)),
    'received': ('Đã nhận', Color(0xFF4CAF50)),
    'cancelled': ('Đã hủy', Color(0xFFF44336)),
    'refund_requested': ('Yêu cầu hoàn tiền', Color(0xFFFF9800)),
    'refunded': ('Đã hoàn tiền', Color(0xFF009688)),
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
