// lib/features/order/screens/order_tracking_screen.dart

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/socket_client.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';
import '../../../core/widgets/app_button.dart';

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// Provider trả về { order, storeDetails }
final orderDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await DioClient.instance.get(ApiEndpoints.orderDetail(id));
  final order = Map<String, dynamic>.from(res.data['order'] ?? res.data);
  final storeDetails = res.data['storeDetails'] as Map<String, dynamic>?;
  if (storeDetails != null) order['_storeDetails'] = storeDetails;
  return order;
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
  bool _loadingAction = false;
  bool _uploadingReceipt = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _subscribeSocket();
  }

  void _subscribeSocket() {
    final sc = SocketClient();
    sc.joinOrderRoom(widget.orderId);
    // Re-join room sau khi socket reconnect (app ở background rồi quay lại)
    sc.on('connect', (_) => sc.joinOrderRoom(widget.orderId));
    sc.onOrderStatusChanged((data) {
      if (data['orderId'] == widget.orderId && mounted) {
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });
    sc.onPaymentStatusChanged((data) {
      if (data['orderId'] == widget.orderId && mounted) {
        ref.invalidate(orderDetailProvider(widget.orderId));
      }
    });
  }

  // Polling fallback cho quán VIP chờ Sepay xác nhận — phòng khi socket miss event
  void _startPolling() {
    if (_pollTimer?.isActive ?? false) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    final sc = SocketClient();
    sc.leaveOrderRoom(widget.orderId);
    sc.off('connect');
    sc.off('order_status_changed');
    sc.off('payment_status_changed');
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    setState(() => _loadingAction = true);
    try {
      await DioClient.instance.post(ApiEndpoints.orderReportPaid(widget.orderId), data: {});
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (e) {
      if (mounted) {
        String msg = 'Có lỗi xảy ra, vui lòng thử lại';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map) {
            msg = (data['message'] ?? data['error'] ?? msg).toString();
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loadingAction = true);
    try {
      await DioClient.instance.post(ApiEndpoints.orderConfirmReceived(widget.orderId), data: {});
      ref.invalidate(orderDetailProvider(widget.orderId));
      if (mounted) _tabCtrl.animateTo(1); // chuyển sang tab đánh giá
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
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
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
      await DioClient.instance.post(ApiEndpoints.orderCancel(widget.orderId), data: {});
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingAction = false);
    }
  }

  Future<void> _uploadReceipt() async {
    final svc = ref.read(imageServiceProvider);
    final picked = await svc.pickSingle();
    if (picked == null || !mounted) return;

    setState(() => _uploadingReceipt = true);
    try {
      final uploaded =
          await svc.uploadXFile(picked, context: ImageUploadContext.receipt);

      await DioClient.instance.post(
        ApiEndpoints.orderPaymentUpload(widget.orderId),
        data: {'receiptUrl': uploaded.url},
      );
      ref.invalidate(orderDetailProvider(widget.orderId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã upload biên lai thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    // Bật polling khi VIP store + bank_transfer + chưa thanh toán
    // Tắt ngay khi đã paid hoặc không cần thiết
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      orderDetailProvider(widget.orderId),
      (_, next) => next.whenData((order) {
        final paymentStatus = order['paymentStatus'] as String? ?? '';
        final isPaid = paymentStatus == 'paid_full' || paymentStatus == 'cod_collected';
        final paymentMethod = order['paymentMethod'] as String? ?? '';
        final isBank = paymentMethod == 'bank_transfer' || paymentMethod == 'fifty_fifty';
        final storeDetails = order['_storeDetails'] as Map<String, dynamic>?;
        final isVip = (storeDetails?['vipTier'] as String? ?? 'none') != 'none';
        if (isVip && isBank && !isPaid) {
          _startPolling();
        } else {
          _stopPolling();
        }
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => ref.invalidate(orderDetailProvider(widget.orderId)),
          ),
        ],
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
              uploadingReceipt: _uploadingReceipt,
              onConfirmPayment: _confirmPayment,
              onConfirmReceived: _confirmReceived,
              onCancel: _cancelOrder,
              onUploadReceipt: _uploadReceipt,
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

// ─────────────────────────────────────────────────────────────────────────────
// _TrackingTab
// ─────────────────────────────────────────────────────────────────────────────

class _TrackingTab extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool loadingAction;
  final bool uploadingReceipt;
  final VoidCallback onConfirmPayment;
  final VoidCallback onConfirmReceived;
  final VoidCallback onCancel;
  final VoidCallback onUploadReceipt;

  const _TrackingTab({
    required this.order,
    required this.loadingAction,
    required this.uploadingReceipt,
    required this.onConfirmPayment,
    required this.onConfirmReceived,
    required this.onCancel,
    required this.onUploadReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = order['mainStatus'] as String? ?? '';
    final paymentStatus = order['paymentStatus'] as String? ?? '';
    final paymentMethod = order['paymentMethod'] as String? ?? '';
    final storeDetails = order['_storeDetails'] as Map<String, dynamic>?;
    final storeId = (order['storeId'] as String?) ?? '';
    final receiver = order['receiver'] as Map<String, dynamic>?;
    final deliveryAddr = order['deliveryAddress'] as Map<String, dynamic>?;
    final bank = order['storeBankSnapshot'] as Map<String, dynamic>?;
    final receiptUrl = order['bankTransferReceiptUrl'] as String?;
    final foodPhotos = (order['foodPhotos'] as List<dynamic>?) ?? [];
    final itemsTotal = (order['itemsTotal'] as num?)?.toDouble() ?? 0.0;
    final shipFee = (order['shipFee'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final isCancelled = status == 'cancelled';
    final isBank = paymentMethod == 'bank_transfer' || paymentMethod == 'fifty_fifty';
    final isPaid =
        paymentStatus == 'paid_full' || paymentStatus == 'cod_collected';

    // Quán VIP → đối soát tự động qua Sepay (nếu hết VIP thì trở lại thủ công)
    final storeVipTier = storeDetails?['vipTier'] as String? ?? 'none';
    final isStoreVip = storeVipTier != 'none';
    // Nội dung CK: VIP thêm prefix SEVQR, non-VIP giữ nguyên order code
    final orderCode = order['code'] as String? ?? '';
    final transferContent = isStoreVip ? 'SEVQR $orderCode' : orderCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Mã đơn hàng ──────────────────────────────────────────────────
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
                        const Text('Mã đơn hàng',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        OrderCodeText(code: order['code'] as String? ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Trạng thái ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trạng thái đơn hàng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  if (isCancelled)
                    const Row(
                      children: [
                        Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Đơn hàng đã bị hủy',
                            style: TextStyle(
                                color: Colors.red, fontWeight: FontWeight.w500)),
                      ],
                    )
                  else
                    _StatusStepper(status: status),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Thông tin cửa hàng ────────────────────────────────────────────
          if (storeDetails != null)
            _InfoCard(
              title: 'Thông tin cửa hàng',
              rows: [
                _InfoRow(Icons.store_outlined,
                    storeDetails['name'] as String? ?? ''),
                if ((storeDetails['addressText'] as String? ?? '').isNotEmpty)
                  _InfoRow(Icons.location_on_outlined,
                      storeDetails['addressText'] as String),
                if ((storeDetails['phone'] as String? ?? '').isNotEmpty)
                  _InfoRow(Icons.phone_outlined,
                      storeDetails['phone'] as String),
              ],
            ),
          if (storeDetails != null) const SizedBox(height: 12),

          // ── Thông tin người nhận ──────────────────────────────────────────
          if (receiver != null)
            _InfoCard(
              title: 'Thông tin người nhận',
              rows: [
                _InfoRow(Icons.person_outlined,
                    receiver['name'] as String? ?? ''),
                _InfoRow(Icons.phone_outlined,
                    receiver['phone'] as String? ?? ''),
                if ((deliveryAddr?['text'] as String? ?? '').isNotEmpty)
                  _InfoRow(Icons.location_on_outlined,
                      deliveryAddr!['text'] as String),
              ],
            ),
          if (receiver != null) const SizedBox(height: 12),

          // ── Danh sách món + tổng tiền ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách món',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...(order['items'] as List? ?? []).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${item['nameSnapshot']} x${item['qty']}',
                                    style: const TextStyle(fontSize: 14))),
                            Text(
                                _vnd.format(
                                    (item['priceSnapshot'] as num) *
                                        (item['qty'] as num)),
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      )),
                  const Divider(height: 16),
                  _summaryRow(
                      'Tiền hàng:', _vnd.format(itemsTotal),
                      color: Colors.grey.shade700),
                  const SizedBox(height: 4),
                  _summaryRow(
                    'Phí ship:',
                    shipFee == 0 ? 'Miễn phí' : _vnd.format(shipFee),
                    color: shipFee == 0 ? Colors.green : Colors.grey.shade700,
                  ),
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng cộng:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        _vnd.format(totalAmount),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── QR VietQR (chuyển khoản) ──────────────────────────────────────
          if (isBank && bank != null && !isCancelled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('QR chuyển khoản',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _VietQRImage(
                      bank: bank['bank'] as String? ?? '',
                      accountNo: bank['number'] as String? ?? '',
                      accountName: bank['holder'] as String? ?? '',
                      amount: totalAmount.toInt(),
                      description: transferContent,
                    ),
                    const SizedBox(height: 10),
                    _infoRow(Icons.account_balance_outlined,
                        '${bank['bank'] ?? ''} — ${bank['number'] ?? ''}'),
                    _infoRow(Icons.person_outlined,
                        bank['holder'] as String? ?? ''),
                    const SizedBox(height: 4),
                    if (isStoreVip)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD700)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt,
                                size: 15, color: Color(0xFF92700A)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Nội dung CK: $transferContent',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92700A),
                                    fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              tooltip: 'Sao chép',
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: transferContent));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Đã sao chép nội dung CK')),
                                );
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Nội dung CK: $transferContent',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            tooltip: 'Sao chép',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: transferContent));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Đã sao chép nội dung')),
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Thanh toán / Biên lai ─────────────────────────────────────────
          if (isBank && !isCancelled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thanh toán',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _PaymentStatusChip(status: paymentStatus),
                    const SizedBox(height: 10),

                    if (isStoreVip) ...[
                      // ── Quán VIP ──────────────────────────────────────────
                      if (!isPaid) ...[
                        // Đang chờ Sepay xác nhận
                        Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF4B400),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Đang chờ Sepay xác nhận tự động...\nChuyển khoản đúng nội dung "$transferContent" để được xác nhận ngay.',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF92700A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      // ── Upload biên lai tuỳ chọn — hiển thị cả sau khi đã thanh toán
                      if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: receiptUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => const SizedBox(
                              height: 80,
                              child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      AppButton(
                        label: receiptUrl != null && receiptUrl.isNotEmpty
                            ? 'Upload lại biên lai (tuỳ chọn)'
                            : 'Upload biên lai (tuỳ chọn)',
                        onPressed: uploadingReceipt ? null : onUploadReceipt,
                        isLoading: uploadingReceipt,
                        variant: ButtonVariant.outlined,
                      ),
                    ] else ...[
                      // ── Quán không VIP: thủ công như cũ ──────────────────
                      if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: receiptUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 120,
                              child:
                                  Center(child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => const SizedBox(
                              height: 80,
                              child: Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (!isPaid)
                        AppButton(
                          label: receiptUrl != null && receiptUrl.isNotEmpty
                              ? 'Upload lại biên lai'
                              : 'Upload biên lai',
                          onPressed:
                              uploadingReceipt ? null : onUploadReceipt,
                          isLoading: uploadingReceipt,
                          variant: ButtonVariant.outlined,
                        ),
                      if (paymentStatus == 'unpaid') ...[
                        const SizedBox(height: 8),
                        AppButton(
                          label: 'Xác nhận đã chuyển khoản',
                          onPressed: loadingAction ? null : onConfirmPayment,
                          isLoading: loadingAction,
                          variant: ButtonVariant.primary,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Ảnh quán chuẩn bị / giao hàng ────────────────────────────────
          if (foodPhotos.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hình ảnh từ cửa hàng',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: foodPhotos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: foodPhotos[i] as String,
                            width: 160,
                            height: 160,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 160,
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              width: 160,
                              height: 160,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions ───────────────────────────────────────────────────────
          if (_canConfirmReceived(status, paymentMethod, paymentStatus))
            AppButton(
              label: 'Xác nhận đã nhận hàng',
              onPressed: loadingAction ? null : onConfirmReceived,
              isLoading: loadingAction,
              variant: ButtonVariant.primary,
            ),
          if (status == 'pending_store' ||
              status == 'awaiting_payment' ||
              status == 'awaiting_store_open') ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Hủy đơn hàng',
              onPressed: loadingAction ? null : onCancel,
              isLoading: loadingAction,
              variant: ButtonVariant.danger,
            ),
          ],

          // ── Điều hướng ────────────────────────────────────────────────────
          const SizedBox(height: 16),
          Row(
            children: [
              if (storeId.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/store/$storeId'),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('Mua tiếp'),
                  ),
                ),
              if (storeId.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/home'),
                  icon: const Icon(Icons.home_outlined, size: 18),
                  label: const Text('Trang chủ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static bool _canConfirmReceived(
      String status, String paymentMethod, String paymentStatus) {
    // Cho phép từ khi quán nhận đơn (preparing) trở đi
    const allowedStatuses = ['preparing', 'delivering', 'delivered'];
    if (!allowedStatuses.contains(status)) return false;
    switch (paymentMethod) {
      case 'cod':
        return true;
      case 'bank_transfer':
      case 'fifty_fifty':
        return paymentStatus == 'reported_paid' || paymentStatus == 'paid_full';
      default:
        return false;
    }
  }

  static Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );

  static Widget _summaryRow(String label, String value, {Color? color}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, color: color ?? Colors.grey.shade700)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  const _InfoCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.icon, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(r.text,
                              style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VietQR Image
// ─────────────────────────────────────────────────────────────────────────────

class _VietQRImage extends StatelessWidget {
  final String bank;
  final String accountNo;
  final String accountName;
  final int amount;
  final String description;

  const _VietQRImage({
    required this.bank,
    required this.accountNo,
    required this.accountName,
    required this.amount,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    if (bank.isEmpty || accountNo.isEmpty) {
      return const Center(
        child: Text('Không có thông tin tài khoản ngân hàng',
            style: TextStyle(color: Colors.grey)),
      );
    }

    final encodedName = Uri.encodeComponent(accountName);
    final encodedDesc = Uri.encodeComponent(description);
    final qrUrl =
        'https://img.vietqr.io/image/$bank-$accountNo-compact2.png'
        '?amount=$amount&addInfo=$encodedDesc&accountName=$encodedName';

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        child: CachedNetworkImage(
          imageUrl: qrUrl,
          placeholder: (_, __) => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Không tạo được QR.\nVui lòng chuyển khoản thủ công.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// StatusStepper
// ─────────────────────────────────────────────────────────────────────────────

class _StatusStepper extends StatelessWidget {
  final String status;
  const _StatusStepper({required this.status});

  static const _steps = [
    ('pending_store', 'Chờ xác nhận', Icons.hourglass_empty),
    ('preparing', 'Đang chuẩn bị', Icons.check_circle_outline),
    ('delivering', 'Đang giao', Icons.delivery_dining),
    ('delivered', 'Đã giao', Icons.home_outlined),
    ('completed', 'Đã nhận', Icons.done_all),
  ];

  int get _currentIdx {
    final s =
        (status == 'awaiting_payment' || status == 'awaiting_store_open')
            ? 'pending_store'
            : status;
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].$1 == s) return i;
    }
    return status == 'cancelled' ? -1 : 0;
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
                    color: isDone
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                  child: Icon(step.$3,
                      size: 16,
                      color: isDone ? Colors.white : Colors.grey),
                ),
                if (i < _steps.length - 1)
                  Container(
                    width: 2,
                    height: 24,
                    color: i < idx
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                step.$2,
                style: TextStyle(
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
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

// ─────────────────────────────────────────────────────────────────────────────
// PaymentStatusChip
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentStatusChip extends StatelessWidget {
  final String status;
  const _PaymentStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'paid_full':
      case 'cod_collected':
        color = const Color(0xFF4CAF50);
        label = 'Đã thanh toán';
        break;
      case 'reported_paid':
        color = const Color(0xFF2196F3);
        label = 'Đang xác minh';
        break;
      case 'partial':
        color = const Color(0xFF9C27B0);
        label = 'Thanh toán một phần';
        break;
      case 'unpaid':
        color = const Color(0xFFFFC107);
        label = 'Chưa thanh toán';
        break;
      case 'cod_pending':
        color = const Color(0xFFFF9800);
        label = 'Thu tiền khi nhận';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Chip(
      label: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReviewTab
// ─────────────────────────────────────────────────────────────────────────────

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
  Map<String, dynamic>? _existingReview;
  bool _checkingReview = true;

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  Future<void> _loadExistingReview() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.orderReviews(widget.orderId));
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _existingReview = data['storeReview'] as Map<String, dynamic>?;
          _checkingReview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkingReview = false);
    }
  }

  Future<void> _submitReview() async {
    setState(() => _loading = true);
    try {
      final res = await DioClient.instance.post(
        ApiEndpoints.orderReview(widget.orderId),
        data: {'stars': _rating, 'comment': _commentCtrl.text.trim()},
      );
      if (mounted) setState(() => _existingReview = res.data as Map<String, dynamic>?);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        await _loadExistingReview();
        return;
      }
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
    final status = widget.order['mainStatus'] as String? ?? '';
    final canReview = status == 'completed';

    if (_checkingReview) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_existingReview != null) {
      final stars = (_existingReview!['stars'] as num?)?.toInt() ?? 0;
      final comment = _existingReview!['comment'] as String? ?? '';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 56),
              const SizedBox(height: 12),
              const Text('Bạn đã đánh giá đơn hàng này',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 28,
                  color: i < stars ? Colors.amber : Colors.grey.shade300,
                )),
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(comment,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black87)),
              ],
            ],
          ),
        ),
      );
    }

    if (!canReview) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Nhấn "Xác nhận đã nhận hàng" ở tab Theo dõi để mở khóa đánh giá.',
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
          const Text('Đánh giá đơn hàng',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Mức độ hài lòng:',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => IconButton(
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              ),
            ),
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
