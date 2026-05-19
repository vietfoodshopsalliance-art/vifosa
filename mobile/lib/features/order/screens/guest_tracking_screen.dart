// lib/features/order/screens/guest_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/order_code_text.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// Tracking công khai theo orderCode + token (không cần đăng nhập)
final guestTrackingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String code, String? token})>((ref, args) async {
  final queryParams = <String, dynamic>{'code': args.code};
  if (args.token != null) queryParams['t'] = args.token;
  final res = await DioClient().dio.get('/track', queryParameters: queryParams);
  return Map<String, dynamic>.from(res.data['order'] ?? res.data);
});

class GuestTrackingScreen extends ConsumerWidget {
  final String orderCode;
  final String? token;

  const GuestTrackingScreen({
    super.key,
    required this.orderCode,
    this.token,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(
      guestTrackingProvider((code: orderCode, token: token)),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi đơn hàng'),
        centerTitle: true,
        // Không có back button nếu vào từ link ngoài
      ),
      body: orderAsync.when(
        data: (order) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.store_outlined, size: 40, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order['storeName'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            const Text('Cửa hàng', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Order code
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mã đơn hàng', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 4),
                      OrderCodeText(code: orderCode),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 12),
                      _GuestStatusDisplay(status: order['status'] ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Delivery address
              if (order['deliveryAddress'] != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Địa chỉ giao', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(order['deliveryAddress']),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Items
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      ...(order['items'] as List? ?? []).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text('${item['name']} x${item['quantity']}')),
                            Text(_vnd.format(item['price'] * item['quantity'])),
                          ],
                        ),
                      )),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tổng:', style: TextStyle(fontWeight: FontWeight.bold)),
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

              // Download app banner
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tải ứng dụng Vifosa',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Đặt món yêu thích mọi lúc mọi nơi',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                      onPressed: () {
                        // TODO: link to Play Store
                      },
                      child: Text('Tải về', style: TextStyle(color: theme.colorScheme.primary)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Không tìm thấy đơn hàng', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                  guestTrackingProvider((code: orderCode, token: token)),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestStatusDisplay extends StatelessWidget {
  final String status;
  const _GuestStatusDisplay({required this.status});

  static const _steps = [
    ('pending', 'Chờ xác nhận'),
    ('accepted', 'Đã xác nhận'),
    ('delivering', 'Đang giao'),
    ('delivered', 'Đã giao'),
    ('received', 'Đã nhận'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentIdx = _steps.indexWhere((s) => s.$1 == status);

    if (status == 'cancelled') {
      return const Row(
        children: [
          Icon(Icons.cancel, color: Color(0xFFF44336)),
          SizedBox(width: 8),
          Text('Đơn hàng đã bị hủy', style: TextStyle(color: Color(0xFFF44336), fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Row(
      children: _steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isDone = i <= currentIdx;
        final isActive = i == currentIdx;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? theme.colorScheme.primary : Colors.grey.shade300,
                  border: isActive ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                ),
                child: Icon(
                  isDone ? Icons.check : Icons.circle,
                  size: isDone ? 16 : 8,
                  color: isDone ? Colors.white : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.$2,
                style: TextStyle(
                  fontSize: 10,
                  color: isDone ? theme.colorScheme.primary : Colors.grey,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}