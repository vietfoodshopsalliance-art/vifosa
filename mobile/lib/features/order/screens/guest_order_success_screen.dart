// lib/features/order/screens/guest_order_success_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/env.dart';
import '../../../core/widgets/order_code_text.dart';

class GuestOrderSuccessScreen extends StatelessWidget {
  final String code;
  final String token;
  final String storeName;
  final Map<String, dynamic>? storeBankAccount;
  final int totalAmount;

  const GuestOrderSuccessScreen({
    super.key,
    required this.code,
    required this.token,
    required this.storeName,
    this.storeBankAccount,
    required this.totalAmount,
  });

  String get _trackingLink =>
      '${Env.trackingBaseUrl}/track/$code?t=$token';

  @override
  Widget build(BuildContext context) {
    final vnd = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

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
            Text(storeName,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),

            // ── Mã đơn hàng ──────────────────────────────────────────────
            _InfoCard(
              children: [
                const Text('Mã đơn hàng',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    OrderCodeText(code: code),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 18, color: Colors.grey),
                      tooltip: 'Sao chép mã',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
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

            // ── Thông tin CK ─────────────────────────────────────────────
            if (storeBankAccount != null) ...[
              _InfoCard(
                color: const Color(0xFFFFF8E1),
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance,
                          size: 16, color: Color(0xFFE65100)),
                      SizedBox(width: 6),
                      Text(
                        'Chuyển khoản 100% trước',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _BankRow('Số TK',
                      storeBankAccount!['number']?.toString() ?? ''),
                  _BankRow('Ngân hàng',
                      storeBankAccount!['bank']?.toString() ?? ''),
                  _BankRow('Tên TK',
                      storeBankAccount!['holder']?.toString() ?? ''),
                  const Divider(height: 16),
                  _BankRow(
                    'Số tiền',
                    vnd.format(totalAmount),
                    bold: true,
                    color: const Color(0xFFE53935),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nội dung CK: $code [tên của bạn]',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── QR code ───────────────────────────────────────────────────
            _InfoCard(
              children: [
                const Text('QR theo dõi đơn hàng',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                Center(
                  child: QrImageView(
                    data: _trackingLink,
                    version: QrVersions.auto,
                    size: 180,
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
                      'Theo dõi đơn hàng $code: $_trackingLink',
                      subject: 'Đơn hàng Vifosa $code',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Nút Zalo
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
                onPressed: () async {
                  final shareText = Uri.encodeComponent(
                      'Theo dõi đơn $code: $_trackingLink');
                  final url =
                      Uri.parse('https://zalo.me/?text=$shareText');
                  if (!await launchUrl(url,
                      mode: LaunchMode.externalApplication)) {
                    Share.share(
                        'Theo dõi đơn hàng $code: $_trackingLink');
                  }
                },
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
                onPressed: () =>
                    context.pushReplacement('/track?code=$code&t=$token'),
                child: const Text(
                  'Theo dõi đơn hàng',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
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
