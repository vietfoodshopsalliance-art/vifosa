// lib/features/cart/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../cart/screens/cart_screen.dart' show cartProvider, CartState, CartNotifier;

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

// Fetch danh sách payment methods quán hỗ trợ
final _storePaymentMethodsProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, storeId) async {
  if (storeId.isEmpty) return ['cod'];
  final res = await DioClient.instance.get(ApiEndpoints.storeById(storeId));
  final raw = res.data as Map<String, dynamic>;
  final store = (raw['store'] ?? raw) as Map<String, dynamic>;
  final pm = store['paymentMethods'] as Map? ?? {};
  final supported = <String>[];
  if (pm['cod'] == true) supported.add('cod');
  if (pm['bankTransfer'] == true) supported.add('bank_transfer');
  if (pm['fiftyFifty'] == true) supported.add('fifty_fifty');
  return supported.isEmpty ? ['cod'] : supported;
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressCtrl    = TextEditingController();
  final _noteCtrl       = TextEditingController();
  final _receiverNameCtrl  = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  String _paymentMethod  = 'cod';
  String _deliveryMethod = 'store_delivery';
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_receiverNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập tên người nhận');
      return;
    }
    if (_receiverPhoneCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập số điện thoại người nhận');
      return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập địa chỉ nhận hàng');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final cart = ref.read(cartProvider);
    final Map<String, List<dynamic>> grouped = {};
    for (final item in cart.items) {
      grouped.putIfAbsent(item.storeId, () => []).add({
        'itemId': item.itemId,
        'quantity': item.quantity,
        'price': item.price,
      });
    }
    try {
      String? firstOrderId;
      for (final entry in grouped.entries) {
        final res = await DioClient.instance.post(ApiEndpoints.orders, data: {
          'storeId': entry.key,
          'items': entry.value,
          'deliveryMethod': _deliveryMethod,
          'deliveryAddress': {'text': _addressCtrl.text.trim()},
          'receiver': {
            'name': _receiverNameCtrl.text.trim(),
            'phone': _receiverPhoneCtrl.text.trim(),
          },
          'paymentMethod': _paymentMethod,
          'customerNote': _noteCtrl.text.trim(),
        });
        firstOrderId ??= res.data['order']?['_id'] ?? res.data['_id'];
      }
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      if (firstOrderId != null) {
        context.go('/order/$firstOrderId');
      } else {
        context.go('/orders');
      }
    } catch (e, st) {
      debugPrint('=== ORDER ERROR: $e');
      debugPrint('$st');
      setState(() => _errorMsg = 'Không thể đặt hàng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final storeId = cart.storeId ?? '';
    final pmAsync = ref.watch(_storePaymentMethodsProvider(storeId));

    // Auto-select phương thức đầu tiên khi load xong
    ref.listen(_storePaymentMethodsProvider(storeId), (_, next) {
      next.whenData((methods) {
        if (!methods.contains(_paymentMethod)) {
          setState(() => _paymentMethod = methods.first);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receiver info
            const Text('Thông tin người nhận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _receiverNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Họ tên người nhận *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _receiverPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Số điện thoại *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // Delivery method
            const Text('Hình thức giao hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            RadioListTile<String>(
              value: 'store_delivery',
              groupValue: _deliveryMethod,
              onChanged: (v) => setState(() => _deliveryMethod = v!),
              title: const Text('Quán tự giao'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'self_pickup',
              groupValue: _deliveryMethod,
              onChanged: (v) => setState(() => _deliveryMethod = v!),
              title: const Text('Tự đến lấy'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'customer_shipper',
              groupValue: _deliveryMethod,
              onChanged: (v) => setState(() => _deliveryMethod = v!),
              title: const Text('Tự thuê shipper'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 12),

            // Delivery address
            const Text('Địa chỉ nhận hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Nhập địa chỉ cụ thể (số nhà, đường, phường/xã, quận/huyện...)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 20),

            // Order items summary
            const Text('Đơn hàng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ...cart.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('${item.name} x${item.quantity}', style: const TextStyle(fontSize: 14))),
                          Text(_vnd.format(item.price * item.quantity), style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _vnd.format(cart.subtotal),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment method
            const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            pmAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Không tải được phương thức thanh toán',
                  style: TextStyle(color: Colors.red, fontSize: 13)),
              data: (methods) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...methods.map((m) => RadioListTile<String>(
                    value: m,
                    groupValue: _paymentMethod,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                    title: Text(_pmLabel(m)),
                    secondary: Icon(_pmIcon(m)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  if (_paymentMethod == 'bank_transfer')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        'Thông tin chuyển khoản sẽ hiển thị sau khi đặt hàng thành công.',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Note
            const Text('Ghi chú (tùy chọn)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ghi chú cho cửa hàng...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
              ),

            AppButton(
              label: 'Đặt hàng',
              onPressed: _loading ? null : _placeOrder,
              isLoading: _loading,
              variant: ButtonVariant.primary,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _pmLabel(String method) => switch (method) {
    'cod'          => 'Tiền mặt khi nhận hàng (COD)',
    'bank_transfer'=> 'Chuyển khoản ngân hàng',
    'fifty_fifty'  => '50/50 (nửa tiền mặt, nửa chuyển khoản)',
    _              => method,
  };

  IconData _pmIcon(String method) => switch (method) {
    'cod'          => Icons.payments_outlined,
    'bank_transfer'=> Icons.account_balance_outlined,
    'fifty_fifty'  => Icons.compare_arrows_outlined,
    _              => Icons.payment_outlined,
  };
}
