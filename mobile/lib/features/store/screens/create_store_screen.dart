//C:\Users\Admin\develop\vifosa\mobile\lib\features\store\screens\create_store_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/store_providers.dart';
import '../screens/create_store_screen.dart';

const _dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addrTextCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();
  final _bankNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();

  double? _lat, _lng;
  bool _saving = false;

  final List<Map<String, dynamic>> _hours = List.generate(
    7,
    (i) => {'dayOfWeek': i, 'open': '08:00', 'close': '22:00', 'isClosed': false},
  );

  final Map<String, bool> _paymentMethods = {
    'bankTransfer': true,
    'cod': false,
    'fiftyFifty': false,
    'momo': false,
    'zaloPay': false,
  };

  (double, double)? _extractLatLng(String url) {
    final q = RegExp(r'[?&]q=(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (q != null) return (double.parse(q.group(1)!), double.parse(q.group(2)!));
    final at = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),').firstMatch(url);
    if (at != null) return (double.parse(at.group(1)!), double.parse(at.group(2)!));
    return null;
  }

  void _parseMaps() {
    final ll = _extractLatLng(_mapsCtrl.text.trim());
    if (ll != null) setState(() { _lat = ll.$1; _lng = ll.$2; });
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần nhập toạ độ địa chỉ quán')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final store = await ref.read(storeNotifierProvider.notifier).createStore({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'address': {
          'text': _addrTextCtrl.text.trim(),
          'location': {'type': 'Point', 'coordinates': [_lng, _lat]},
        },
        'openingHours': _hours,
        'bankAccount': {
          'number': _bankNumberCtrl.text.trim(),
          'bank': _bankNameCtrl.text.trim(),
          'holder': _bankHolderCtrl.text.trim(),
        },
        'paymentMethods': _paymentMethods,
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => StoreDashboardScreen(storeId: store.id)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo quán mới')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Thông tin cơ bản', [
                  _field('Tên quán *', _nameCtrl),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Mô tả quán',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
                _section('Địa chỉ quán', [
                  _field('Địa chỉ (text)', _addrTextCtrl),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('Paste link Google Maps', _mapsCtrl)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _parseMaps,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Parse'),
                    ),
                  ]),
                  if (_lat != null) ...[
                    const SizedBox(height: 8),
                    Text('Toạ độ: $_lat, $_lng',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 180,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(_lat!, _lng!),
                          initialZoom: 15,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.vifosa.app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: LatLng(_lat!, _lng!),
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 36),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ]),
                _section('Giờ mở cửa', [
                  ..._hours.asMap().entries.map((e) {
                    final i = e.key;
                    final h = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 32,
                          child: Text(_dayLabels[h['dayOfWeek']],
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        Checkbox(
                          value: !h['isClosed'],
                          onChanged: (v) => setState(
                              () => _hours[i]['isClosed'] = !(v ?? true)),
                        ),
                        Expanded(
                          child: Row(children: [
                            _timeField(h['open'], h['isClosed'], (v) =>
                                setState(() => _hours[i]['open'] = v)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('→'),
                            ),
                            _timeField(h['close'], h['isClosed'], (v) =>
                                setState(() => _hours[i]['close'] = v)),
                          ]),
                        ),
                      ]),
                    );
                  }),
                ]),
                _section('Tài khoản ngân hàng', [
                  _field('Số tài khoản', _bankNumberCtrl),
                  const SizedBox(height: 8),
                  _field('Ngân hàng', _bankNameCtrl),
                  const SizedBox(height: 8),
                  _field('Chủ tài khoản', _bankHolderCtrl),
                ]),
                _section('Phương thức thanh toán', [
                  ..._paymentMethods.entries.map((e) {
                    final labels = {
                      'bankTransfer': 'Chuyển khoản ngân hàng',
                      'cod': 'COD (tiền mặt)',
                      'fiftyFifty': '50/50',
                      'momo': 'MoMo',
                      'zaloPay': 'ZaloPay',
                    };
                    return CheckboxListTile(
                      dense: true,
                      value: e.value,
                      title: Text(labels[e.key] ?? e.key),
                      onChanged: (v) =>
                          setState(() => _paymentMethods[e.key] = v ?? false),
                    );
                  }),
                ]),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submit,
                  child: const Text('Tạo quán', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        ...children,
        const Divider(height: 24),
      ]),
    );
  }

  Widget _field(String hint, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _timeField(String value, bool disabled, void Function(String) onChanged) {
    return InkWell(
      onTap: disabled
          ? null
          : () async {
              final parts = value.split(':');
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: int.parse(parts[0]),
                  minute: int.parse(parts[1]),
                ),
              );
              if (picked != null) {
                onChanged(
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: disabled ? Colors.grey.shade300 : Colors.grey),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(value,
            style: TextStyle(color: disabled ? Colors.grey.shade400 : Colors.black)),
      ),
    );
  }
}
