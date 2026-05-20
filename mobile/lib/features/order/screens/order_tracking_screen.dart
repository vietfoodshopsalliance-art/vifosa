// lib/features/order/screens/order_tracking_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/widgets/order_code_text.dart';
import '../../../core/widgets/app_button.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

final orderDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await DioClient.instance.get(ApiEndpoints.orderDetail(id));
  return Map<String, dynamic>.from(res.data['order'] ?? res.data);
});

class OrderTrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Map<String, dynamic>? _liveOrder;
  bool _loadingAction = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _subscribeSocket();
  }

  // THAY bằng:
  void _subscribeSocket() {
    final sc = SocketClient();
    sc.joinOrderRoom(widget.orderId);
    sc.onOrderStatusChanged((data) {
      if (data['orderId'] == widget.orderId && mounted) {
        setState(() => _liveOrder = Map<String, dynamic>.from(data));
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });
  }

  @override
  void dispose() {
    final sc = SocketClient();
    sc.leaveOrderRoom(widget.orderId);
    sc.off('order_status_changed');
    sc.off('payment_status_changed');
    _tabCtrl.dispose();
    super.dispose();
  }

  

  Future<void> _confirmPayment() async {
    setState(() => _loadingAction = true);
    try {
      await DioClient.instance.post(ApiEndpoints.orderReportPaid(widget.orderId));
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')),
      );
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _confirmReceived() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận đã nhận hàng'),
        content: const Text('Bạn xác nhận đã nhận được hàng?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loadingAction = true);
    try {
      await DioClient.instance.post(ApiEndpoints.orderConfirmReceived(widget.orderId));
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hủy đơn hàng'),
        content: const Text('Bạn có chắc muốn hủy đơn hàng này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy đơn', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loadingAction = true);
    try {
      await DioClient.instance.post(ApiEndpoints.orderCancel(widget.orderId));
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Theo dõi'),
            Tab(text: 'Đánh giá'),
          ],
        ),
      ),
      body: orderAsync.when(
        data: (order) => TabBarView(
          controller: _tabCtrl,
          children: [
            _TrackingTab(
              order: order,
              loadingAction: _loadingAction,
              onConfirmPayment: _confirmPayment,
              onConfirmReceived: _confirmReceived,
              onCancel: _cancelOrder,
            ),
            _ReviewTab(orderId: widget.orderId, order: order),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không thể tải đơn hàng'),
              TextButton(
                onPressed: () => ref.invalidate(orderDetailProvider(widget.orderId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingTab extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool loadingAction;
  final VoidCallback onConfirmPayment;
  final VoidCallback onConfirmReceived;
  final VoidCallback onCancel;

  const _TrackingTab({
    required this.order,
    required this.loadingAction,
    required this.onConfirmPayment,
    required this.onConfirmReceived,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = order['status'] ?? '';
    final paymentStatus = order['paymentStatus'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order code
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mã đơn hàng', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        OrderCodeText(code: order['orderCode'] ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status stepper
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trạng thái đơn hàng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _StatusStepper(status: status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment info
          if (order['paymentMethod'] == 'bank_transfer')
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thanh toán chuyển khoản',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (order['bankInfo'] != null) ...[
                      Text('Ngân hàng: ${order['bankInfo']['bankName'] ?? ''}'),
                      Text('Số tài khoản: ${order['bankInfo']['accountNumber'] ?? ''}'),
                      Text('Tên tài khoản: ${order['bankInfo']['accountName'] ?? ''}'),
                      const SizedBox(height: 4),
                      Text(
                        'Nội dung: ${order['orderCode'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _PaymentStatusChip(status: paymentStatus),
                    const SizedBox(height: 8),
                    if (paymentStatus == 'pending' && status != 'cancelled')
                      AppButton(
                        label: 'Xác nhận đã chuyển khoản',
                        onPressed: loadingAction ? null : onConfirmPayment,
                        isLoading: loadingAction,
                        variant: ButtonVariant.primary,
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách món',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
          const SizedBox(height: 16),

          // Actions
          if (status == 'delivered')
            AppButton(
              label: 'Xác nhận đã nhận hàng',
              onPressed: loadingAction ? null : onConfirmReceived,
              isLoading: loadingAction,
              variant: ButtonVariant.primary,
            ),
          if (status == 'pending')
            AppButton(
              label: 'Hủy đơn hàng',
              onPressed: loadingAction ? null : onCancel,
              isLoading: loadingAction,
              variant: ButtonVariant.danger,
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = [
    ('pending', 'Chờ xác nhận', Icons.hourglass_empty),
    ('accepted', 'Đã xác nhận', Icons.check_circle_outline),
    ('delivering', 'Đang giao', Icons.delivery_dining),
    ('delivered', 'Đã giao', Icons.home_outlined),
    ('received', 'Đã nhận', Icons.done_all),
  ];

  int get _currentIdx {
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == status) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = _currentIdx;
    return Column(
      children: _steps.asMap().entries.map((entry) {
        final i = entry.key;
        final step = entry.value;
        final isDone = i <= idx;
        final isActive = i == idx;
        return Row(
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone ? theme.colorScheme.primary : Colors.grey.shade300,
                  ),
                  child: Icon(step.$3, size: 16, color: isDone ? Colors.white : Colors.grey),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: i < idx ? theme.colorScheme.primary : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                step.$2,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  final String status;
  const _PaymentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'paid': color = const Color(0xFF4CAF50); label = 'Đã thanh toán'; break;
      case 'pending': color = const Color(0xFFFFC107); label = 'Chờ thanh toán'; break;
      default: color = Colors.grey; label = status;
    }
    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ReviewTab extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic> order;
  const _ReviewTab({required this.orderId, required this.order});

  @override
  ConsumerState<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends ConsumerState<_ReviewTab> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  Future<void> _submitReview() async {
    setState(() => _loading = true);
    try {
      await DioClient.instance.post(
        ApiEndpoints.orderReview(widget.orderId),
        data: {'rating': _rating, 'comment': _commentCtrl.text.trim()},
      );
      setState(() => _submitted = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể gửi đánh giá')),
      );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canReview = widget.order['status'] == 'received' && widget.order['reviewedAt'] == null;

    if (_submitted || widget.order['reviewedAt'] != null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 56),
            SizedBox(height: 12),
            Text('Cảm ơn bạn đã đánh giá!', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (!canReview) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Bạn có thể đánh giá sau khi đơn hàng được xác nhận là đã nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đánh giá đơn hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Mức độ hài lòng:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) => IconButton(
              icon: Icon(
                i < _rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 36,
              ),
              onPressed: () => setState(() => _rating = i + 1),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Chia sẻ cảm nhận của bạn...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Gửi đánh giá',
            onPressed: _loading ? null : _submitReview,
            isLoading: _loading,
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}
