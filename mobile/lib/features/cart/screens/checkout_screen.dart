// lib/features/cart/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../cart_provider.dart' show cartProvider;

final _vnd = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _paymentMethod = 'cod'; // 'cod' | 'bank_transfer'
  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập địa chỉ nhận hàng');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    final cart = ref.read(cartProvider);
    final storeId = cart.storeId;
    if (storeId == null || cart.items.isEmpty) {
      setState(() => _errorMsg = 'Giỏ hàng trống');
      setState(() => _loading = false);
      return;
    }
    final items = cart.items.map((item) => {
      'itemId': item.itemId,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();
    try {
      final res = await DioClient.instance.post(ApiEndpoints.orders, data: {
        'storeId': storeId,
        'items': items,
        'deliveryAddress': _addressCtrl.text.trim(),
        'paymentMethod': _paymentMethod,
        'note': _noteCtrl.text.trim(),
      });
      final firstOrderId = res.data['order']?['_id'] ?? res.data['_id'];
      ref.read(cartProvider.notifier).clearCart();
      if (!mounted) return;
      if (firstOrderId != null) {
        context.go('/order/$firstOrderId');
      } else {
        context.go('/orders');
      }
    } catch (e) {
      setState(() => _errorMsg = 'Không thể đặt hàng. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            RadioListTile<String>(
              value: 'cod',
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              title: const Text('Tiền mặt khi nhận hàng (COD)'),
              secondary: const Icon(Icons.payments_outlined),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              value: 'bank_transfer',
              groupValue: _paymentMethod,
              onChanged: (v) => setState(() => _paymentMethod = v!),
              title: const Text('Chuyển khoản ngân hàng'),
              secondary: const Icon(Icons.account_balance_outlined),
              contentPadding: EdgeInsets.zero,
            ),
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
}