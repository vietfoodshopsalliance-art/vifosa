// lib/features/store_dashboard/orders/store_order_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';
import '../models/store_order.dart';

final _currency = NumberFormat('#,##0', 'vi_VN');

class StoreOrderDetailScreen extends ConsumerStatefulWidget {
  final StoreOrder order;
  /// null = history / read-only view
  final VoidCallback? onDeliver;
  final VoidCallback? onReturnToPending;
  final void Function(double amount)? onRecordPayment;

  const StoreOrderDetailScreen({
    super.key,
    required this.order,
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
        context: ImageUploadContext.storeAvatar,
      );
      await DioClient.instance.post(
        '/orders/${widget.order.id}/food-photos',
        data: {'url': result.url},
      );
      if (mounted) {
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
                if (o.foodPhotos.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: o.foodPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          o.foodPhotos[i],
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
