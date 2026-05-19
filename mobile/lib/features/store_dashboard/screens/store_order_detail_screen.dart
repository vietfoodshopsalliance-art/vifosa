// lib/features/store_dashboard/screens/store_order_detail_screen.dart
// Req 6.10 — Màn hình chi tiết đơn hàng phía chủ quán

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';
import '../../../core/widgets/app_button.dart';
import '../../order/screens/order_tracking_screen.dart' show orderDetailProvider;

// ─── Helpers ─────────────────────────────────────────────────────────────────

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
final _dtFmt = DateFormat('HH:mm dd/MM/yyyy');

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    return _dtFmt.format(DateTime.parse(iso).toLocal());
  } catch (_) {
    return '';
  }
}

String _fmtCurrency(double v) => _vnd.format(v);

String _maskPhone(String phone) {
  if (phone.length < 10) return phone;
  return '${phone.substring(0, 4)} xxx ${phone.substring(phone.length - 3)}';
}

IconData _deliveryIcon(String m) => switch (m) {
      'store_delivery' => Icons.delivery_dining,
      'self_pickup' => Icons.storefront_outlined,
      'customer_shipper' => Icons.directions_bike_outlined,
      _ => Icons.local_shipping_outlined,
    };

String _deliveryLabel(String m) => switch (m) {
      'store_delivery' => 'Quán giao',
      'self_pickup' => 'Khách tự lấy',
      'customer_shipper' => 'Shipper riêng',
      _ => m,
    };

String _paymentMethodLabel(String m) => switch (m) {
      'cod' => 'COD (thu khi giao)',
      'bank_transfer' => 'Chuyển khoản',
      'fifty_fifty' => '50/50 (CK + COD)',
      'momo' => 'MoMo',
      'zalo_pay' => 'ZaloPay',
      _ => m,
    };

// ─── Screen ───────────────────────────────────────────────────────────────────

class StoreOrderDetailScreen extends ConsumerStatefulWidget {
  final String storeId;
  final String orderId;

  const StoreOrderDetailScreen({
    super.key,
    required this.storeId,
    required this.orderId,
  });

  @override
  ConsumerState<StoreOrderDetailScreen> createState() =>
      _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState
    extends ConsumerState<StoreOrderDetailScreen> {
  bool _loadingAction = false;
  final List<String> _foodPhotoUrls = [];
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _subscribeSocket();
  }

  void _subscribeSocket() {
    final sc = SocketClient();
    sc.joinOrderRoom(widget.orderId);
    sc.onOrderStatusChanged((data) {
      if (data['orderId'] == widget.orderId && mounted) {
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });
  }

  @override
  void dispose() {
    final sc = SocketClient();
    sc.leaveOrderRoom(widget.orderId);
    sc.off('order_status_changed');
    super.dispose();
  }

  Future<void> _doAction(Future<void> Function() action) async {
    setState(() => _loadingAction = true);
    try {
      await action();
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _acceptOrder() => _doAction(() async {
        final client = ref.read(dioClientProvider);
        await client.dio
            .post(ApiEndpoints.storeAcceptOrder(widget.orderId), data: {});
      });

  Future<void> _rejectOrder() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lý do từ chối'),
        content: TextField(
          controller: reasonCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Lý do *',
            hintText: 'Vd: Hết nguyên liệu...',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _doAction(() async {
      final client = ref.read(dioClientProvider);
      await client.dio.post(
        ApiEndpoints.storeRejectOrder(widget.orderId),
        data: {'reason': reasonCtrl.text.trim()},
      );
    });
  }

  Future<void> _handoverOrder() => _doAction(() async {
        final client = ref.read(dioClientProvider);
        await client.dio.post(
          ApiEndpoints.storeHandoverOrder(widget.orderId),
          data: _foodPhotoUrls.isEmpty ? {} : {'foodPhotos': _foodPhotoUrls},
        );
      });

  Future<void> _completeDelivery() => _doAction(() async {
        final client = ref.read(dioClientProvider);
        await client.dio.post(
            ApiEndpoints.storeCompleteDelivery(widget.orderId), data: {});
      });

  Future<void> _returnToPending() => _doAction(() async {
        final client = ref.read(dioClientProvider);
        await client.dio.post(
            ApiEndpoints.storeReturnOrder(widget.orderId), data: {});
      });

  Future<void> _confirmMoneyReceived(
      double totalAmount, double paidAmount) async {
    final remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final ctrl =
        TextEditingController(text: remaining.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận đã nhận tiền'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tổng đơn: ${_fmtCurrency(totalAmount)}\n'
              'Đã nhận: ${_fmtCurrency(paidAmount)}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Số tiền nhận lần này (₫)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final amount =
        double.tryParse(ctrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;
    await _doAction(() async {
      final client = ref.read(dioClientProvider);
      await client.dio.post(
        ApiEndpoints.storeConfirmMoney(widget.orderId),
        data: {'amount': amount},
      );
    });
  }

  Future<void> _pickAndUploadFoodPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final svc = ref.read(imageServiceProvider);
      final result = await svc.uploadFile(
        File(picked.path),
        context: ImageUploadContext.menuItem,
      );
      if (mounted) setState(() => _foodPhotoUrls.add(result.url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được hình, thử lại')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn hàng')),
      body: orderAsync.when(
        data: (order) => _buildBody(context, order),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Không thể tải đơn hàng'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(orderDetailProvider(widget.orderId)),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> order) {
    final theme = Theme.of(context);
    final status = order['mainStatus'] as String? ?? '';
    final paymentMethod = order['paymentMethod'] as String? ?? '';
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (order['paidAmount'] as num?)?.toDouble() ?? 0;
    final remaining =
        (totalAmount - paidAmount).clamp(0.0, double.infinity);
    final isCod = paymentMethod == 'cod';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Order header ────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.receipt_long_outlined, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: OrderCodeText(code: order['code'] ?? '')),
                      _StatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fmtDate(order['createdAt'] as String?),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if ((order['deliveryMethod'] as String?) != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _deliveryIcon(order['deliveryMethod'] as String),
                          size: 14,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _deliveryLabel(
                              order['deliveryMethod'] as String),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Customer info ───────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thông tin khách hàng',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.person_outline,
                    text:
                        order['receiver']?['name'] as String? ?? '—',
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: _maskPhone(
                        order['receiver']?['phone'] as String? ?? '—'),
                    onTap: () {
                      final phone =
                          order['receiver']?['phone'] as String? ?? '';
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép SĐT'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  if ((order['deliveryAddress']?['text'] as String? ?? '')
                      .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      text: order['deliveryAddress']['text'] as String,
                    ),
                  ],
                  if ((order['customerNote'] as String? ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.sticky_note_2_outlined,
                      text: order['customerNote'] as String,
                      color: Colors.orange.shade700,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Items ───────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách món',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...(order['items'] as List? ?? []).map((item) {
                    final price = (item['priceSnapshot'] as num?) ?? 0;
                    final qty = (item['qty'] as num?) ?? 1;
                    final note = item['note'] as String?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item['nameSnapshot']} × $qty',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(_fmtCurrency(
                                  (price * qty).toDouble())),
                            ],
                          ),
                          if (note != null && note.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '  Ghi chú: $note',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Phí giao hàng',
                          style: TextStyle(color: Colors.grey)),
                      (order['shipFee'] ?? 0) == 0
                          ? const Text('Miễn phí',
                              style: TextStyle(color: Colors.green))
                          : Text(_fmtCurrency(
                              (order['shipFee'] as num).toDouble())),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng cộng',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        _fmtCurrency(totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Payment ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Thanh toán',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Phương thức: ',
                          style: TextStyle(color: Colors.grey)),
                      Text(_paymentMethodLabel(paymentMethod)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Đã nhận: ',
                          style: TextStyle(color: Colors.grey)),
                      Text(
                        _fmtCurrency(paidAmount),
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                  // Còn phải thu — chỉ non-COD
                  if (!isCod) ...[
                    const SizedBox(height: 10),
                    if (remaining > 0)
                      GestureDetector(
                        onTap: _loadingAction
                            ? null
                            : () => _confirmMoneyReceived(
                                totalAmount, paidAmount),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_outlined,
                                  size: 16,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Còn phải thu: ${_fmtCurrency(remaining)}',
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          const Text(
                            'Còn phải thu: 0 đ',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Food photo upload (chỉ khi đang chuẩn bị) ──────────────────
          if (status == 'preparing')
            _FoodPhotoCard(
              photoUrls: _foodPhotoUrls,
              isUploading: _isUploadingPhoto,
              onAdd: _pickAndUploadFoodPhoto,
              onRemove: (i) =>
                  setState(() => _foodPhotoUrls.removeAt(i)),
            ),
          if (status == 'preparing') const SizedBox(height: 12),

          // ── Action buttons ──────────────────────────────────────────────
          _buildActionButtons(status),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    final isLoading = _loadingAction;

    switch (status) {
      case 'pending_store':
      case 'awaiting_store_open':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Nhận đơn',
              onPressed: isLoading ? null : _acceptOrder,
              isLoading: isLoading,
              variant: ButtonVariant.primary,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Từ chối đơn',
              onPressed: isLoading ? null : _rejectOrder,
              variant: ButtonVariant.danger,
            ),
          ],
        );
      case 'preparing':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(
              label: 'Giao cho shipper / Khách đến lấy',
              onPressed: isLoading ? null : _handoverOrder,
              isLoading: isLoading,
              variant: ButtonVariant.primary,
            ),
            const SizedBox(height: 8),
            AppButton(
              label: '← Trả lại chờ xử lý',
              onPressed: isLoading ? null : _returnToPending,
              variant: ButtonVariant.outlined,
            ),
          ],
        );
      case 'delivering':
        return AppButton(
          label: 'Xác nhận đã giao',
          onPressed: isLoading ? null : _completeDelivery,
          isLoading: isLoading,
          variant: ButtonVariant.primary,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Food Photo Card ──────────────────────────────────────────────────────────

class _FoodPhotoCard extends StatelessWidget {
  final List<String> photoUrls;
  final bool isUploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  const _FoodPhotoCard({
    required this.photoUrls,
    required this.isUploading,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Hình món đã chuẩn bị / đã giao hàng',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        tooltip: 'Thêm hình',
                        onPressed: onAdd,
                      ),
              ],
            ),
            if (photoUrls.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Chưa có hình — nhấn + để upload',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          photoUrls[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: Center(
                                          child:
                                              CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                    ),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending_store' => ('Chờ xác nhận', Colors.orange),
      'awaiting_store_open' => ('Đặt trước', Colors.purple),
      'preparing' => ('Đang chuẩn bị', Colors.blue),
      'delivering' => ('Đang giao', Colors.teal),
      'delivered' => ('Đã giao', Colors.green),
      'completed' => ('Hoàn thành', Colors.green),
      'cancelled' => ('Đã hủy', Colors.red),
      _ => (status, Colors.grey),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child:
                Icon(Icons.copy_outlined, size: 13, color: Colors.grey),
          ),
      ],
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: row) : row;
  }
}
