// lib/features/order/screens/guest_tracking_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';

final _vnd =
    NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// Tracking công khai theo orderCode + token (không cần đăng nhập)
final guestTrackingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String code, String? token})>(
        (ref, args) async {
  final queryParams = <String, dynamic>{'code': args.code};
  if (args.token != null) queryParams['t'] = args.token;
  final res =
      await DioClient.instance.get('/track', queryParameters: queryParams);
  return Map<String, dynamic>.from(res.data['order'] ?? res.data);
});

class GuestTrackingScreen extends ConsumerStatefulWidget {
  final String orderCode;
  final String? token;

  const GuestTrackingScreen({
    super.key,
    required this.orderCode,
    this.token,
  });

  @override
  ConsumerState<GuestTrackingScreen> createState() =>
      _GuestTrackingScreenState();
}

class _GuestTrackingScreenState extends ConsumerState<GuestTrackingScreen> {
  bool _uploadingReceipt = false;
  String? _newReceiptUrl; // URL vừa upload trong session này

  bool get _hasToken =>
      widget.token != null && widget.token!.isNotEmpty;

  String get _trackingLink =>
      '${Env.trackingBaseUrl}/track/${widget.orderCode}?t=${widget.token ?? ''}';

  Future<void> _uploadReceipt() async {
    if (!_hasToken) return;
    final svc = ref.read(imageServiceProvider);
    final picked = await svc.pickSingle();
    if (picked == null || !mounted) return;

    setState(() => _uploadingReceipt = true);
    try {
      final uploaded =
          await svc.uploadXFile(picked, context: ImageUploadContext.receipt);

      // Guest upload endpoint — xác thực bằng code + token
      await DioClient.instance.post(
        '/track/upload-receipt',
        queryParameters: {'code': widget.orderCode, 't': widget.token},
        data: {'receiptUrl': uploaded.url},
      );

      setState(() => _newReceiptUrl = uploaded.url);

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

  Future<void> _shareZalo() async {
    // Thử deep link Zalo, fallback về system share
    final zaloUri = Uri(
      scheme: 'zalo',
      host: 'forward',
      queryParameters: {'l': _trackingLink},
    );
    if (!await launchUrl(zaloUri,
        mode: LaunchMode.externalNonBrowserApplication)) {
      await Share.share(
        'Theo dõi đơn hàng ${widget.orderCode}: $_trackingLink',
        subject: 'Đơn hàng Vifosa ${widget.orderCode}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(
      guestTrackingProvider((code: widget.orderCode, token: widget.token)),
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi đơn hàng'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: () => ref.invalidate(
              guestTrackingProvider(
                  (code: widget.orderCode, token: widget.token)),
            ),
          ),
        ],
      ),
      body: orderAsync.when(
        data: (order) => _buildContent(order, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Không tìm thấy đơn hàng',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(
                  guestTrackingProvider(
                      (code: widget.orderCode, token: widget.token)),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> order, ThemeData theme) {
    final isBank = order['paymentMethod'] == 'bank_transfer';
    final isPaid = order['paymentStatus'] == 'paid_full';
    final isVip = (order['storeVipTier'] as String? ?? 'none') != 'none';
    final bank = order['storeBankSnapshot'] as Map<String, dynamic>?;
    final existingReceiptUrl = order['bankTransferReceiptUrl'] as String?;
    final displayReceiptUrl = _newReceiptUrl ?? existingReceiptUrl;
    final transferContent =
        isVip ? 'SEVQR ${widget.orderCode}' : widget.orderCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Store info ────────────────────────────────────────────────────
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
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        const Text('Cửa hàng',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Order code ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mã đơn hàng',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      OrderCodeText(code: widget.orderCode),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy,
                            size: 18, color: Colors.grey),
                        tooltip: 'Sao chép',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.orderCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép mã đơn'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Status ────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trạng thái',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  _GuestStatusDisplay(status: order['status'] ?? ''),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Delivery address ──────────────────────────────────────────────
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
                          const Text('Địa chỉ giao',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(order['deliveryAddress']),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // ── Items ─────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đơn hàng',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  ...(order['items'] as List? ?? []).map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    '${item['name']} x${item['quantity']}')),
                            Text(_vnd.format((item['price'] as num) *
                                (item['quantity'] as num))),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tổng:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 12),

          // ── Payment section ───────────────────────────────────────────────
          if (isBank && bank != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          isPaid ? Icons.check_circle : Icons.qr_code,
                          size: 16,
                          color: isPaid
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF1D7A4E),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isPaid
                                ? 'Đã thanh toán'
                                : (isVip
                                    ? 'QR chuyển khoản (tự động đối soát)'
                                    : 'QR chuyển khoản'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isPaid
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF1D7A4E),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // QR + transfer info — chỉ hiển thị khi chưa thanh toán
                    if (!isPaid) ...[
                      const SizedBox(height: 10),
                      _VietQRImage(
                        bank: bank['bank'] as String? ?? '',
                        accountNo: bank['number'] as String? ?? '',
                        accountName: bank['holder'] as String? ?? '',
                        amount: (order['totalAmount'] as num).toInt(),
                        description: transferContent,
                      ),
                    ],

                    const SizedBox(height: 10),
                    _BankRow('Số TK', bank['number']?.toString() ?? ''),
                    _BankRow('Ngân hàng', bank['bank']?.toString() ?? ''),
                    _BankRow('Tên TK', bank['holder']?.toString() ?? ''),
                    const Divider(height: 16),
                    _BankRow(
                      'Số tiền',
                      _vnd.format(order['totalAmount'] ?? 0),
                      bold: true,
                      color: isPaid
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935),
                    ),

                    // Nội dung chuyển khoản — chỉ khi chưa thanh toán
                    if (!isPaid) ...[
                      const SizedBox(height: 8),
                      if (isVip)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFFFD700)),
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
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: transferContent));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Đã sao chép nội dung CK')),
                                  );
                                },
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
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(
                                    ClipboardData(text: transferContent));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Đã sao chép nội dung CK')),
                                );
                              },
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Receipt upload ────────────────────────────────────────────
            if (_hasToken)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Biên lai chuyển khoản',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      if (isVip)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Đơn VIP được đối soát tự động. Upload biên lai là tuỳ chọn.',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (displayReceiptUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: displayReceiptUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const SizedBox(
                              height: 120,
                              child: Center(
                                  child: CircularProgressIndicator()),
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
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: _uploadingReceipt
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.upload_file_outlined,
                                  size: 18),
                          label: Text(_uploadingReceipt
                              ? 'Đang upload...'
                              : displayReceiptUrl != null
                                  ? 'Upload lại biên lai${isVip ? ' (tuỳ chọn)' : ''}'
                                  : 'Upload biên lai${isVip ? ' (tuỳ chọn)' : ''}'),
                          onPressed:
                              _uploadingReceipt ? null : _uploadReceipt,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],

          // ── Download app banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 0.7)
                ],
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
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(height: 4),
                      Text('Đặt món yêu thích mọi lúc mọi nơi',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  onPressed: () {
                    // TODO: link to Play Store
                  },
                  child: Text('Tải về',
                      style:
                          TextStyle(color: theme.colorScheme.primary)),
                ),
              ],
            ),
          ),

          // ── Share buttons (chỉ khi có token) ─────────────────────────────
          if (_hasToken) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Sao chép link'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _trackingLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép link'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Chia sẻ'),
                    onPressed: () => Share.share(
                      'Theo dõi đơn hàng ${widget.orderCode}: $_trackingLink',
                      subject: 'Đơn hàng Vifosa ${widget.orderCode}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send,
                    size: 16, color: Color(0xFF0068FF)),
                label: const Text('Chia sẻ qua Zalo',
                    style: TextStyle(color: Color(0xFF0068FF))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0068FF)),
                ),
                onPressed: _shareZalo,
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── VietQR Image ──────────────────────────────────────────────────────────────

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
    final qrUrl = 'https://img.vietqr.io/image/$bank-$accountNo-compact2.png'
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
            height: 100,
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

// ── Bank Row ──────────────────────────────────────────────────────────────────

class _BankRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _BankRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                fontSize: bold ? 15 : 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Display ────────────────────────────────────────────────────────────

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
          Text('Đơn hàng đã bị hủy',
              style: TextStyle(
                  color: Color(0xFFF44336), fontWeight: FontWeight.bold)),
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
                  color: isDone
                      ? theme.colorScheme.primary
                      : Colors.grey.shade300,
                  border: isActive
                      ? Border.all(
                          color: theme.colorScheme.primary, width: 2)
                      : null,
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
                  color:
                      isDone ? theme.colorScheme.primary : Colors.grey,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal,
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
