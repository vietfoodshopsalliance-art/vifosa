// lib/features/store_dashboard/orders/store_order_detail_screen.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';
import '../models/store_order.dart';
import '../reviews/customer_review_dialog.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

class StoreOrderDetailScreen extends ConsumerStatefulWidget {
  final StoreOrder order;
  final String? storeId;
  /// null = history / read-only view
  final VoidCallback? onDeliver;
  final VoidCallback? onReturnToPending;
  final void Function(double amount)? onRecordPayment;

  const StoreOrderDetailScreen({
    super.key,
    required this.order,
    this.storeId,
    this.onDeliver,
    this.onReturnToPending,
    this.onRecordPayment,
  });

  @override
  ConsumerState<StoreOrderDetailScreen> createState() =>
      _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState
    extends ConsumerState<StoreOrderDetailScreen> {
  bool _uploading = false;
  late List<String> _foodPhotos;

  // Review state
  Map<String, dynamic>? _orderReviews;
  bool _reviewLoading = false;
  bool _reviewFetchError = false;

  @override
  void initState() {
    super.initState();
    _foodPhotos = List<String>.from(widget.order.foodPhotos);
    _refreshFoodPhotos();
    _fetchOrderReviews();
  }

  Future<void> _fetchOrderReviews() async {
    if (widget.storeId == null) return;
    final o = widget.order;
    if (!['delivered', 'completed'].contains(o.mainStatus)) return;
    setState(() {
      _reviewLoading = true;
      _reviewFetchError = false;
    });
    try {
      final res = await DioClient.instance.get(ApiEndpoints.orderReviews(o.id));
      if (mounted) {
        setState(() {
          _orderReviews = res.data as Map<String, dynamic>;
          _reviewFetchError = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reviewFetchError = true);
    } finally {
      if (mounted) setState(() => _reviewLoading = false);
    }
  }

  bool get _canReviewCustomer =>
      _orderReviews != null && (_orderReviews!['canReviewCustomer'] as bool? ?? false);

  Map<String, dynamic>? get _existingCustomerReview =>
      _orderReviews?['customerReview'] as Map<String, dynamic>?;

  Future<void> _submitCustomerReview({
    required int stars,
    required String comment,
    required List<String> images,
    required bool isAnonymous,
  }) async {
    try {
      await DioClient.instance.post(
        ApiEndpoints.orderCustomerReview(widget.order.id),
        data: {
          'stars': stars,
          'comment': comment,
          'images': images,
          'isAnonymous': isAnonymous,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // Review đã tồn tại — refresh để hiển thị đúng rồi thoát bình thường
        await _fetchOrderReviews();
        return;
      }
      final msg = (e.response?.data as Map?)?['error'] as String?;
      throw Exception(msg ?? 'Gửi đánh giá thất bại');
    }
    await _fetchOrderReviews();
  }

  Future<void> _refreshFoodPhotos() async {
    try {
      final res = await DioClient.instance
          .get(ApiEndpoints.orderDetail(widget.order.id));
      final data = res.data is Map ? res.data as Map<String, dynamic> : <String, dynamic>{};
      final order = (data['order'] ?? data) as Map<String, dynamic>;
      final photos = (order['foodPhotos'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (mounted) setState(() => _foodPhotos = photos);
    } catch (_) {
      // giữ nguyên snapshot nếu fetch lỗi
    }
  }

  String get _deliverBtnLabel {
    if (widget.order.paymentMethod == 'cod') return 'Đã giao cho khách';
    return 'Giao hàng';
  }

  String _deliveryMethodLabel(String m) {
    switch (m) {
      case 'store_delivery': return '🛵 Quán giao';
      case 'self_pickup': return '🚶 Khách tự lấy';
      case 'customer_shipper': return '🚚 Shipper riêng';
      default: return m;
    }
  }

  String _paymentMethodLabel(String m) {
    switch (m) {
      case 'bank_transfer': return 'Chuyển khoản';
      case 'cod': return 'COD (tiền mặt)';
      case 'fifty_fifty': return '50/50';
      default: return m;
    }
  }

  String _paymentStatusLabel(String s) {
    const map = {
      'unpaid': 'Chưa thanh toán',
      'reported_paid': 'Đã báo CK',
      'partial': 'Trả 1 phần',
      'paid_full': 'Đã thanh toán đủ',
      'cod_pending': 'COD – chưa thu',
      'cod_collected': 'COD – đã thu',
    };
    return map[s] ?? s;
  }

  Future<void> _uploadFoodPhoto() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final svc = ref.read(imageServiceProvider);
      final result = await svc.uploadFile(
        File(file.path),
        context: ImageUploadContext.foodPhoto,
      );
      await DioClient.instance.post(
        ApiEndpoints.orderFoodPhotos(widget.order.id),
        data: {'photoUrl': result.url},
      );
      if (mounted) {
        setState(() => _foodPhotos.add(result.url));
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã tải ảnh lên')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: AppBar(
        title: OrderCodeText(code: o.code, suffixFontSize: 17),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Customer info ────────────────────────────────────────────
          if (widget.storeId != null &&
              o.customerId != null &&
              o.customerId!.isNotEmpty) ...[
            _CustomerCard(
              storeId: widget.storeId!,
              customerId: o.customerId!,
              recipientName: o.recipientName,
            ),
            const SizedBox(height: 12),
          ],

          // ── Status ──────────────────────────────────────────────────
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Trạng thái', _statusLabel(o.mainStatus)),
                _row('Phương thức', _paymentMethodLabel(o.paymentMethod)),
                _row('Thanh toán', _paymentStatusLabel(o.paymentStatus)),
                _row('Giao hàng', _deliveryMethodLabel(o.deliveryMethod)),
                if (o.deliveryAddressText.isNotEmpty)
                  _row('Địa chỉ', o.deliveryAddressText),
                if (o.recipientName != null)
                  _row('Người nhận', o.recipientName!),
                if (o.recipientPhone != null)
                  _row('Điện thoại', o.recipientPhone!),
                if (o.note != null && o.note!.isNotEmpty)
                  _row('Ghi chú', o.note!),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Items ───────────────────────────────────────────────────
          _Section(
            title: 'Món ăn',
            child: Column(
              children: [
                ...o.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text('${item.name}  ×${item.quantity}')),
                        Text(
                            '${_currency.format(item.price * item.quantity)} đ',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                        if (item.note != null && item.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text('  ↳ ${item.note}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 12),
                _row('Tạm tính', '${_currency.format(o.subtotal)} đ'),
                _row('Phí ship', '${_currency.format(o.shipFee)} đ'),
                _boldRow('Tổng', '${_currency.format(o.total)} đ'),
                if (o.remainingAmount > 0)
                  _boldRow(
                    'Còn phải thu',
                    '${_currency.format(o.remainingAmount)} đ',
                    color: Colors.orange.shade700,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Payment receipt photo ────────────────────────────────────
          if (o.bankTransferReceiptUrl != null) ...[
            _Section(
              title: 'Ảnh chuyển khoản của khách',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  o.bankTransferReceiptUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Text('Không tải được ảnh'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Food photos ───────────────────────────────────────────────
          _Section(
            title: 'Ảnh món đã chuẩn bị / bàn giao',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_foodPhotos.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _foodPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _foodPhotos[i],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadFoodPhoto,
                  icon: _uploading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label:
                      Text(_uploading ? 'Đang tải...' : 'Thêm ảnh'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Cancel info ───────────────────────────────────────────────
          if (o.cancelInfo != null) ...[
            _Section(
              title: 'Thông tin hủy',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row('Người hủy', o.cancelInfo!.cancelledBy),
                  _row('Lý do', o.cancelInfo!.reason),
                  _row(
                    'Thời gian',
                    DateFormat('HH:mm dd/MM/yyyy')
                        .format(o.cancelInfo!.cancelledAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Customer review ───────────────────────────────────────────
          if (widget.storeId != null &&
              o.customerId != null &&
              o.customerId!.isNotEmpty &&
              ['delivered', 'completed'].contains(o.mainStatus)) ...[
            _Section(
              title: 'Đánh giá khách hàng',
              child: _reviewLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _reviewFetchError
                      ? Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Không tải được thông tin đánh giá',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchOrderReviews,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        )
                      : _existingCustomerReview != null
                          ? _ExistingCustomerReview(review: _existingCustomerReview!)
                          : _canReviewCustomer
                              ? SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.star_border, size: 18),
                                    label: const Text('Đánh giá khách hàng'),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (_) => CustomerReviewDialog(
                                        onSubmit: _submitCustomerReview,
                                      ),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Không thể đánh giá (đã quá 30 ngày)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions ───────────────────────────────────────────────────
          if (widget.onDeliver != null || widget.onReturnToPending != null) ...[
            if (widget.onReturnToPending != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade700),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onReturnToPending!();
                },
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Trả lại chờ xử lý'),
              ),
            if (widget.onReturnToPending != null && widget.onDeliver != null)
              const SizedBox(height: 8),
            if (widget.onDeliver != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDeliver!();
                  },
                  child: Text(_deliverBtnLabel),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  String _statusLabel(String s) {
    const map = {
      'pending_store': 'Chờ quán xác nhận',
      'awaiting_payment': 'Chờ thanh toán',
      'awaiting_store_open': 'Chờ quán mở cửa',
      'preparing': 'Đang chuẩn bị',
      'delivering': 'Đang giao hàng',
      'delivered': 'Đã giao',
      'completed': 'Hoàn thành',
      'cancelled': 'Đã hủy',
    };
    return map[s] ?? s;
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  Widget _boldRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color ?? Colors.black87)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color ?? Colors.black87)),
          ],
        ),
      );
}

// ─── Existing customer review summary ────────────────────────────────────────

class _ExistingCustomerReview extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ExistingCustomerReview({required this.review});

  @override
  Widget build(BuildContext context) {
    final stars = (review['stars'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(5, (i) => Icon(
              i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: i < stars ? Colors.amber : Colors.grey.shade300,
            )),
            const SizedBox(width: 6),
            const Text('Đã đánh giá', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(comment, style: const TextStyle(fontSize: 13)),
        ],
      ],
    );
  }
}

// ─── Customer card ────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final String storeId;
  final String customerId;
  final String? recipientName;
  const _CustomerCard({
    required this.storeId,
    required this.customerId,
    this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
          '/store-dashboard/$storeId/customers/$customerId'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_outline, size: 20, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Khách hàng',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  if (recipientName != null)
                    Text(recipientName!,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            const Text('Xem hồ sơ',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String? title;
  final Widget child;
  const _Section({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}
