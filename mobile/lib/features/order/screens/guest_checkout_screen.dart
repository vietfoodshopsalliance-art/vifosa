// lib/features/order/screens/guest_checkout_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../store/models/store_model.dart' show ShipFeeFormula;

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLng / 2) * sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

class GuestCheckoutArgs {
  final String storeId;
  final String storeName;
  final List<Map<String, dynamic>> items; // [{itemId, name, qty, price}]

  const GuestCheckoutArgs({
    required this.storeId,
    required this.storeName,
    required this.items,
  });
}

class GuestCheckoutScreen extends StatefulWidget {
  final GuestCheckoutArgs args;
  const GuestCheckoutScreen({super.key, required this.args});

  @override
  State<GuestCheckoutScreen> createState() => _GuestCheckoutScreenState();
}

class _GuestCheckoutScreenState extends State<GuestCheckoutScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _noteCtrl       = TextEditingController();
  final _bankNumCtrl    = TextEditingController();
  final _bankNameCtrl   = TextEditingController();
  final _bankHolderCtrl = TextEditingController();

  bool _showBankRefund = false;
  bool _isSubmitting   = false;

  // Tọa độ giao hàng
  double? _deliveryLat, _deliveryLng;

  // Phí ship
  double? _shipFee;
  bool _shipFeeLoading = false;

  static final _vnd = NumberFormat.currency(
    locale: 'vi_VN', symbol: '₫', decimalDigits: 0,
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    _bankNumCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankHolderCtrl.dispose();
    super.dispose();
  }

  int get _itemsTotal => widget.args.items.fold(
    0,
    (sum, i) => sum + ((i['price'] as num) * (i['qty'] as num)).toInt(),
  );

  // ── Tính phí ship ─────────────────────────────────────────────────────────

  Future<void> _fetchShipFee() async {
    if (_deliveryLat == null || _deliveryLng == null) return;
    final storeId = widget.args.storeId;
    if (storeId.isEmpty) return;

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
      debugPrint('GuestCheckout: ship fee error — $e');
      if (mounted) setState(() => _shipFee = null);
    } finally {
      if (mounted) setState(() => _shipFeeLoading = false);
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
          const SnackBar(content: Text('Vui lòng cấp quyền vị trí')),
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
        _shipFee = null;
      });
      _fetchShipFee();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lấy vị trí GPS'),
          duration: Duration(seconds: 1),
        ),
      );
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
                  _shipFee = null;
                });
                _fetchShipFee();
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Không tìm thấy toạ độ trong link này')),
                );
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final guestInfo = <String, dynamic>{
        'name':  _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };
      if (_emailCtrl.text.trim().isNotEmpty) {
        guestInfo['email'] = _emailCtrl.text.trim();
      }
      if (_showBankRefund && _bankNumCtrl.text.trim().isNotEmpty) {
        guestInfo['bankAccountForRefund'] = {
          'number': _bankNumCtrl.text.trim(),
          'bank':   _bankNameCtrl.text.trim(),
          'holder': _bankHolderCtrl.text.trim(),
        };
      }

      final deliveryLng = _deliveryLng ?? 106.6297;
      final deliveryLat = _deliveryLat ?? 10.8231;

      final body = {
        'storeId': widget.args.storeId,
        'items': widget.args.items
            .map((i) => {'itemId': i['itemId'], 'quantity': i['qty']})
            .toList(),
        'guestInfo': guestInfo,
        'deliveryAddress': {
          'text': _addressCtrl.text.trim(),
          'location': {
            'type': 'Point',
            'coordinates': [deliveryLng, deliveryLat],
          },
        },
        'deliveryMethod': 'store_delivery',
        'paymentMethod':  'bank_transfer',
        if (_noteCtrl.text.trim().isNotEmpty)
          'customerNote': _noteCtrl.text.trim(),
      };

      final res = await DioClient.instance
          .post(ApiEndpoints.guestOrders, data: body);

      final orderData = res.data['order'] as Map<String, dynamic>;

      if (mounted) {
        context.pushReplacement('/guest-order-success', extra: {
          'code':             orderData['code'] as String,
          'token':            orderData['trackingToken'] as String,
          'storeName':        orderData['storeName'] as String,
          'storeBankAccount': orderData['storeBankSnapshot'] as Map<String, dynamic>?,
          'totalAmount':      (orderData['totalAmount'] as num).toInt(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đặt hàng: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final effectiveShipFee = _shipFee ?? 0.0;
    final total = _itemsTotal + effectiveShipFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Đặt hàng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Cảnh báo CK trước ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF9800)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFFE65100), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khách vãng lai bắt buộc chuyển khoản 100% trước. Quán xác nhận sau khi nhận được tiền.',
                        style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Thông tin người đặt ──────────────────────────────────────
              _Card(
                title: 'Thông tin người đặt',
                child: Column(
                  children: [
                    _Field(
                      controller: _nameCtrl,
                      label: 'Họ tên *',
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _phoneCtrl,
                      label: 'Số điện thoại *',
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v?.trim().isEmpty == true) return 'Bắt buộc';
                        if (!RegExp(r'^0[0-9]{9}$').hasMatch(v!.trim())) {
                          return 'SĐT không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _emailCtrl,
                      label: 'Email (tuỳ chọn)',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    _Field(
                      controller: _noteCtrl,
                      label: 'Ghi chú (tuỳ chọn)',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Địa chỉ giao hàng + GPS ──────────────────────────────────
              _Card(
                title: 'Địa chỉ giao hàng',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(
                      controller: _addressCtrl,
                      label: 'Địa chỉ *',
                      maxLines: 2,
                      validator: (v) =>
                          v?.trim().isEmpty == true ? 'Bắt buộc' : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _useCurrentGps,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Dùng GPS', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showMapsLinkDialog,
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Link Maps', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_deliveryLat != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Toạ độ: ${_deliveryLat!.toStringAsFixed(4)}, ${_deliveryLng!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Breakdown đơn hàng ───────────────────────────────────────
              _Card(
                title: widget.args.storeName,
                child: Column(
                  children: [
                    // Từng món
                    ...widget.args.items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${i['name']} x${i['qty']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            _vnd.format(
                              ((i['price'] as num) * (i['qty'] as num)).toInt(),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    )),
                    const Divider(height: 16),

                    // Tạm tính
                    _SummaryRow(
                      label: 'Tạm tính:',
                      value: _vnd.format(_itemsTotal),
                    ),
                    const SizedBox(height: 6),

                    // Phí ship
                    if (_shipFeeLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Phí ship:',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey)),
                            SizedBox(
                              width: 80,
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ],
                        ),
                      )
                    else if (_shipFee != null)
                      _SummaryRow(
                        label: 'Phí ship:',
                        value: _vnd.format(_shipFee!),
                      )
                    else
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phí ship:',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey)),
                          Text('Bấm GPS / Maps để tính',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
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
                          _vnd.format(total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── STK nhận hoàn tiền (mở rộng) ────────────────────────────
              InkWell(
                onTap: () =>
                    setState(() => _showBankRefund = !_showBankRefund),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showBankRefund
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Thêm số tài khoản nhận hoàn tiền (tuỳ chọn)',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showBankRefund) ...[
                _Card(
                  title: 'Tài khoản nhận hoàn tiền',
                  child: Column(
                    children: [
                      _Field(
                        controller: _bankNumCtrl,
                        label: 'Số tài khoản',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        controller: _bankNameCtrl,
                        label: 'Tên ngân hàng (VD: Vietcombank)',
                      ),
                      const SizedBox(height: 10),
                      _Field(
                        controller: _bankHolderCtrl,
                        label: 'Tên chủ tài khoản',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ToS
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Bằng cách đặt hàng, bạn đồng ý với Điều khoản dịch vụ của Viet Shops.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor:
                        const Color(0xFFE53935).withOpacity(0.5),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Đặt hàng',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87)),
      ],
    );
  }
}
