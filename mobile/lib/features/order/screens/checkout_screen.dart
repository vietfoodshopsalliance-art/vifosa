// lib/features/order/screens/checkout_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/screens/cart_screen.dart' show cartProvider;
import '../../profile/models/address_model.dart';
import '../../store/models/store_model.dart' show ShipFeeFormula;
import '../../../core/providers/location_provider.dart' show locationProvider;

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

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
  final _receiverNameCtrl  = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _addressCtrl       = TextEditingController();
  final _noteCtrl          = TextEditingController();

  String _paymentMethod  = 'cod';
  String _deliveryMethod = 'store_delivery';
  bool _loading = false;
  String? _errorMsg;

  // Địa chỉ mặc định — dùng để khôi phục khi đổi PT thanh toán
  AddressModel? _defaultAddress;

  // Tọa độ giao hàng (cho phí ship)
  double? _deliveryLat, _deliveryLng;

  // Phí ship
  double? _shipFee;
  bool _shipFeeLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromUser());
  }

  @override
  void dispose() {
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Prefill từ địa chỉ mặc định ─────────────────────────────────────────

  Future<void> _prefillFromUser() async {
    if (ref.read(authProvider).user == null || !mounted) return;

    try {
      final res = await DioClient.instance.get(ApiEndpoints.myAddresses);
      final data = res.data;
      final List<dynamic> list = data is List
          ? data
          : ((data as Map)['addresses'] ?? data['data'] ?? data['items'] ?? []) as List;
      if (list.isEmpty || !mounted) return;

      Map<String, dynamic>? raw;
      for (final a in list) {
        if ((a as Map)['isDefault'] == true) {
          raw = Map<String, dynamic>.from(a);
          break;
        }
      }
      raw ??= Map<String, dynamic>.from(list.first as Map);

      final addr = AddressModel.fromJson(raw);
      _defaultAddress = addr;

      if (!mounted) return;

      double? deliveryLat = (addr.lat != 0.0 || addr.lng != 0.0) ? addr.lat : null;
      double? deliveryLng = (addr.lat != 0.0 || addr.lng != 0.0) ? addr.lng : null;

      // Fallback: nếu địa chỉ lưu không có tọa độ, dùng locationProvider
      if (deliveryLat == null) {
        final gps = await ref.read(locationProvider.future);
        if (mounted) {
          deliveryLat = gps.lat;
          deliveryLng = gps.lng;
        }
      }

      if (!mounted) return;
      setState(() {
        _receiverNameCtrl.text  = addr.receiverName;
        _receiverPhoneCtrl.text = addr.receiverPhone;
        _addressCtrl.text       = addr.text;
        _deliveryLat = deliveryLat;
        _deliveryLng = deliveryLng;
      });
      _fetchShipFee();
    } catch (e) {
      debugPrint('Checkout prefill: $e');
    }
  }

  // ── Phí ship ─────────────────────────────────────────────────────────────

  Future<void> _fetchShipFee() async {
    if (_deliveryMethod == 'self_pickup') {
      if (mounted) setState(() { _shipFee = 0; _shipFeeLoading = false; });
      return;
    }
    final storeId = ref.read(cartProvider).storeId;
    if (storeId == null || storeId.isEmpty) return;
    if (_deliveryLat == null || _deliveryLng == null) return;

    if (mounted) setState(() => _shipFeeLoading = true);
    try {
      final res = await DioClient.instance.get(ApiEndpoints.storeById(storeId));
      final raw = res.data as Map<String, dynamic>;
      final storeData = (raw['store'] ?? raw) as Map<String, dynamic>;

      final formula = ShipFeeFormula.fromJson(
          (storeData['shipFeeFormula'] as Map<String, dynamic>?) ?? {});
      final coords = (storeData['address']?['location']?['coordinates']) as List?;
      if (coords == null || coords.length < 2 || !mounted) {
        if (mounted) setState(() => _shipFeeLoading = false);
        return;
      }
      final storeLng = (coords[0] as num).toDouble();
      final storeLat = (coords[1] as num).toDouble();

      final km = _haversineKm(storeLat, storeLng, _deliveryLat!, _deliveryLng!);
      final fee = (formula.calculate(km) / 1000).round() * 1000.0;
      if (mounted) setState(() => _shipFee = fee);
    } catch (e) {
      debugPrint('Checkout: ship fee error — $e');
      if (mounted) setState(() => _shipFee = null);
    } finally {
      if (mounted) setState(() => _shipFeeLoading = false);
    }
  }

  // ── Đổi hình thức giao hàng ──────────────────────────────────────────────

  void _onDeliveryMethodChanged(String? v) {
    if (v == null) return;
    setState(() {
      _deliveryMethod = v;
      if (v == 'self_pickup') {
        _shipFee = 0;
        _shipFeeLoading = false;
      } else {
        _shipFee = null;
      }
    });
    if (v == 'store_delivery') _fetchShipFee();
  }

  // ── Đổi phương thức thanh toán ───────────────────────────────────────────

  void _onPaymentMethodChanged(String? v) {
    if (v == null) return;
    final prev = _paymentMethod;
    setState(() => _paymentMethod = v);

    // Khôi phục địa chỉ mặc định khi rời khỏi "chuyển khoản"
    if (prev == 'bank_transfer' && v != 'bank_transfer' && _defaultAddress != null) {
      setState(() {
        _receiverNameCtrl.text  = _defaultAddress!.receiverName;
        _receiverPhoneCtrl.text = _defaultAddress!.receiverPhone;
        _addressCtrl.text       = _defaultAddress!.text;
        _deliveryLat = _defaultAddress!.lat != 0.0 ? _defaultAddress!.lat : null;
        _deliveryLng = _defaultAddress!.lng != 0.0 ? _defaultAddress!.lng : null;
      });
      _fetchShipFee();
    }
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _useCurrentGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng cấp quyền vị trí để dùng tính năng này')),
        );
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _deliveryLat = pos.latitude;
        _deliveryLng = pos.longitude;
      });
      _fetchShipFee();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lấy được vị trí: $e')),
        );
      }
    }
  }

  // ── Paste link Google Maps ────────────────────────────────────────────────

  (double, double)? _extractCoords(String text) {
    final r1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final r2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final r3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final m = r1.firstMatch(text) ?? r2.firstMatch(text) ?? r3.firstMatch(text);
    if (m == null) return null;
    return (double.parse(m.group(1)!), double.parse(m.group(2)!));
  }

  void _showMapsLinkDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste link Google Maps'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Paste link tại đây...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              final coords = _extractCoords(ctrl.text.trim());
              if (coords != null) {
                setState(() {
                  _deliveryLat = coords.$1;
                  _deliveryLng = coords.$2;
                });
                _fetchShipFee();
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Không tìm thấy toạ độ trong link này')),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  // ── Đặt hàng ─────────────────────────────────────────────────────────────

  Future<void> _placeOrder() async {
    if (_receiverNameCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập tên người nhận');
      return;
    }
    if (_receiverPhoneCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập số điện thoại người nhận');
      return;
    }
    if (_deliveryMethod == 'store_delivery' && _addressCtrl.text.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập địa chỉ nhận hàng');
      return;
    }

    setState(() { _loading = true; _errorMsg = null; });

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
          'deliveryAddress': {
            'text': _addressCtrl.text.trim(),
            if (_deliveryLat != null && _deliveryLng != null)
              'location': {
                'type': 'Point',
                'coordinates': [_deliveryLng, _deliveryLat],
              },
          },
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
      debugPrint('══ ORDER ERROR ══');
      debugPrint('Type : ${e.runtimeType}');
      debugPrint('Error: $e');
      debugPrint('Stack:\n$st');
      if (mounted) {
        setState(() => _errorMsg = '[${e.runtimeType}] $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final theme = Theme.of(context);
    final storeId = cart.storeId ?? '';
    final pmAsync = ref.watch(_storePaymentMethodsProvider(storeId));

    final isLoggedIn = ref.read(authProvider).user != null;
    // Chỉ cho phép sửa nếu chuyển khoản (hoặc khách vãng lai)
    final canEdit = !isLoggedIn || _paymentMethod == 'bank_transfer';

    // Auto-select phương thức đầu tiên khi load xong
    ref.listen(_storePaymentMethodsProvider(storeId), (_, next) {
      next.whenData((methods) {
        if (!methods.contains(_paymentMethod)) {
          _onPaymentMethodChanged(methods.first);
        }
      });
    });

    final subtotal = cart.subtotal;
    final effectiveShipFee = _deliveryMethod == 'self_pickup' ? 0.0 : (_shipFee ?? 0.0);
    final totalWithShip = subtotal + effectiveShipFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đơn hàng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Thông tin người nhận ──────────────────────────────────────
            const Text('Thông tin người nhận',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),

            TextField(
              controller: _receiverNameCtrl,
              enabled: canEdit,
              decoration: InputDecoration(
                labelText: 'Họ tên người nhận *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outlined),
                filled: !canEdit,
                fillColor: !canEdit ? Colors.grey.shade100 : null,
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _receiverPhoneCtrl,
              enabled: canEdit,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: !canEdit,
                fillColor: !canEdit ? Colors.grey.shade100 : null,
              ),
            ),
            const SizedBox(height: 10),

            // Địa chỉ nhận hàng
            TextField(
              controller: _addressCtrl,
              enabled: canEdit,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Địa chỉ nhận hàng *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: !canEdit,
                fillColor: !canEdit ? Colors.grey.shade100 : null,
              ),
            ),

            // Nút GPS + Maps (chỉ hiện khi canEdit & store_delivery)
            if (canEdit && _deliveryMethod == 'store_delivery') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _useCurrentGps,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('GPS hiện tại', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showMapsLinkDialog,
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Link Maps', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  if (_deliveryLat != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_deliveryLat!.toStringAsFixed(5)}, ${_deliveryLng!.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 20),

            // ── Hình thức giao hàng ───────────────────────────────────────
            const Text('Hình thức giao hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            RadioListTile<String>(
              value: 'store_delivery',
              groupValue: _deliveryMethod,
              onChanged: _onDeliveryMethodChanged,
              title: const Text('Quán tự giao'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            RadioListTile<String>(
              value: 'self_pickup',
              groupValue: _deliveryMethod,
              onChanged: _onDeliveryMethodChanged,
              title: const Text('Khách đến lấy'),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 12),

            // ── Đơn hàng ──────────────────────────────────────────────────
            const Text('Đơn hàng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                          Expanded(
                            child: Text('${item.name} x${item.quantity}',
                                style: const TextStyle(fontSize: 14)),
                          ),
                          Text(_vnd.format(item.price * item.quantity),
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    )),
                    const Divider(height: 16),
                    _summaryRow('Tiền hàng:', _vnd.format(subtotal)),

                    const SizedBox(height: 4),

                    // Phí ship
                    if (_deliveryMethod == 'self_pickup')
                      _summaryRow('Phí ship:', 'Miễn phí',
                          valueColor: Colors.green)
                    else if (_shipFeeLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Phí ship:',
                                style: TextStyle(fontSize: 14, color: Colors.grey)),
                            SizedBox(
                                width: 80,
                                height: 12,
                                child: LinearProgressIndicator()),
                          ],
                        ),
                      )
                    else if (_shipFee != null)
                      _summaryRow('Phí ship:', _vnd.format(_shipFee!))
                    else
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phí ship:',
                              style: TextStyle(fontSize: 14, color: Colors.grey)),
                          Text('Tính khi đặt',
                              style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),

                    const Divider(height: 16),

                    // Tổng cộng
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cộng:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          _vnd.format(totalWithShip),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
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

            // ── Phương thức thanh toán ────────────────────────────────────
            const Text('Phương thức thanh toán',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            pmAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text(
                'Không tải được phương thức thanh toán',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
              data: (methods) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...methods.map((m) => RadioListTile<String>(
                    value: m,
                    groupValue: _paymentMethod,
                    onChanged: _onPaymentMethodChanged,
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

            // ── Ghi chú ───────────────────────────────────────────────────
            const Text('Ghi chú (tùy chọn)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey.shade700)),
      ],
    );
  }

  String _pmLabel(String method) => switch (method) {
    'cod'           => 'Tiền mặt khi nhận hàng (COD)',
    'bank_transfer' => 'Chuyển khoản ngân hàng',
    'fifty_fifty'   => '50/50 (CK trước 50%, CK sau khi nhận hàng 50%)',
    _               => method,
  };

  IconData _pmIcon(String method) => switch (method) {
    'cod'           => Icons.payments_outlined,
    'bank_transfer' => Icons.account_balance_outlined,
    'fifty_fifty'   => Icons.compare_arrows_outlined,
    _               => Icons.payment_outlined,
  };
}
