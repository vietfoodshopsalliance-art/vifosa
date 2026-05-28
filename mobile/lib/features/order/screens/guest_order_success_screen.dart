// lib/features/order/screens/guest_order_success_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../../../core/widgets/order_code_text.dart';

class GuestOrderSuccessScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String code;
  final String token;
  final String storeName;
  final Map<String, dynamic>? storeBankAccount;
  final String storeVipTier;
  final int totalAmount;

  const GuestOrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.code,
    required this.token,
    required this.storeName,
    this.storeBankAccount,
    this.storeVipTier = 'none',
    required this.totalAmount,
  });

  @override
  ConsumerState<GuestOrderSuccessScreen> createState() =>
      _GuestOrderSuccessScreenState();
}

class _GuestOrderSuccessScreenState
    extends ConsumerState<GuestOrderSuccessScreen> {
  bool _uploadingReceipt = false;
  String? _receiptUrl;

  bool get _isStoreVip => widget.storeVipTier != 'none';

  // Nội dung CK: VIP thêm SEVQR, non-VIP giữ nguyên code
  String get _transferContent =>
      _isStoreVip ? 'SEVQR ${widget.code}' : widget.code;

  String get _trackingLink =>
      '${Env.trackingBaseUrl}/track/${widget.code}?t=${widget.token}';

  Future<void> _uploadReceipt() async {
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
        queryParameters: {'code': widget.code, 't': widget.token},
        data: {'receiptUrl': uploaded.url},
      );

      setState(() => _receiptUrl = uploaded.url);

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
        'Theo dõi đơn hàng ${widget.code}: $_trackingLink',
        subject: 'Đơn hàng Vifosa ${widget.code}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vnd = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final bank = widget.storeBankAccount;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Đặt hàng thành công'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Biểu tượng thành công ─────────────────────────────────────
            const SizedBox(height: 8),
            const Icon(Icons.check_circle,
                color: Color(0xFF4CAF50), size: 72),
            const SizedBox(height: 12),
            const Text(
              'Đơn hàng đã được tạo!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 4),
            Text(widget.storeName,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

            // ── Mã đơn hàng ──────────────────────────────────────────────
            _InfoCard(
              children: [
                const Text('Mã đơn hàng',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OrderCodeText(code: widget.code),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 18, color: Colors.grey),
                      tooltip: 'Sao chép mã',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.code));
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
            const SizedBox(height: 12),

            // ── QR chuyển khoản VietQR ───────────────────────────────────
            if (bank != null) ...[
              _InfoCard(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code,
                          size: 16, color: Color(0xFF1D7A4E)),
                      const SizedBox(width: 6),
                      Text(
                        _isStoreVip
                            ? 'QR chuyển khoản (tự động đối soát)'
                            : 'QR chuyển khoản',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D7A4E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _VietQRImage(
                    bank: bank['bank'] as String? ?? '',
                    accountNo: bank['number'] as String? ?? '',
                    accountName: bank['holder'] as String? ?? '',
                    amount: widget.totalAmount,
                    description: _transferContent,
                  ),
                  const SizedBox(height: 10),
                  _BankRow('Số TK', bank['number']?.toString() ?? ''),
                  _BankRow('Ngân hàng', bank['bank']?.toString() ?? ''),
                  _BankRow('Tên TK', bank['holder']?.toString() ?? ''),
                  const Divider(height: 16),
                  _BankRow('Số tiền', vnd.format(widget.totalAmount),
                      bold: true, color: const Color(0xFFE53935)),
                  const SizedBox(height: 8),
                  // Nội dung CK
                  if (_isStoreVip)
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
                              'Nội dung CK: $_transferContent',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF92700A),
                                  fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _transferContent));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Đã sao chép nội dung CK')),
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
                            'Nội dung CK: $_transferContent',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: _transferContent));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Đã sao chép nội dung CK')),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Upload biên lai ────────────────────────────────────────
              _InfoCard(
                children: [
                  const Text('Biên lai chuyển khoản',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (_isStoreVip)
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
                  if (_receiptUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: _receiptUrl!,
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
                          : _receiptUrl != null
                              ? 'Upload lại biên lai${_isStoreVip ? ' (tuỳ chọn)' : ''}'
                              : 'Upload biên lai${_isStoreVip ? ' (tuỳ chọn)' : ''}'),
                      onPressed: _uploadingReceipt ? null : _uploadReceipt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── QR theo dõi đơn hàng ─────────────────────────────────────
            _InfoCard(
              children: [
                const Text('QR theo dõi đơn hàng',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                Center(
                  child: QrImageView(
                    data: _trackingLink,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Scan để theo dõi đơn',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Nút chia sẻ ──────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Sao chép link'),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _trackingLink));
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
                      'Theo dõi đơn hàng ${widget.code}: $_trackingLink',
                      subject: 'Đơn hàng Vifosa ${widget.code}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Nút Zalo — dùng deep link zalo:// với fallback system share
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
            const SizedBox(height: 16),

            // Nút theo dõi đơn
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.pushReplacement(
                    '/track?code=${widget.code}&t=${widget.token}'),
                child: const Text(
                  'Theo dõi đơn hàng',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Về trang chủ'),
            ),
            const SizedBox(height: 32),
          ],
        ),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color? color;
  const _InfoCard({required this.children, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _BankRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _BankRow(this.label, this.value,
      {this.bold = false, this.color});

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
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.normal,
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
