// vifosa/mobile/lib/features/profile/screens/add_address_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/profile_providers.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _labelCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  final _mapsLinkCtrl = TextEditingController();
  final _receiverNameCtrl = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _saving = false;

  // Parse lat/lng from Google Maps URL
  void _parseMapsLink() {
    final url = _mapsLinkCtrl.text.trim();
    final latLng = _extractLatLng(url);
    if (latLng != null) {
      setState(() {
        _lat = latLng.$1;
        _lng = latLng.$2;
        _latCtrl.text = _lat!.toStringAsFixed(6);
        _lngCtrl.text = _lng!.toStringAsFixed(6);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể parse toạ độ từ link này')),
      );
    }
  }

  (double, double)? _extractLatLng(String url) {
    // Pattern 1: ?q=lat,lng
    final q = RegExp(r'[?&]q=(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (q != null) {
      return (double.parse(q.group(1)!), double.parse(q.group(2)!));
    }
    // Pattern 2: @lat,lng,
    final at = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),').firstMatch(url);
    if (at != null) {
      return (double.parse(at.group(1)!), double.parse(at.group(2)!));
    }
    // Pattern 3: /place/.../lat,lng
    final place = RegExp(r'place/[^/]+/(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (place != null) {
      return (double.parse(place.group(1)!), double.parse(place.group(2)!));
    }
    return null;
  }

  void _applyManualCoords() {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat != null && lng != null) setState(() { _lat = lat; _lng = lng; });
  }

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần chọn toạ độ trước')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(addressNotifierProvider.notifier).add({
        'label': _labelCtrl.text.trim(),
        'address': {
          'text': _textCtrl.text.trim(),
          'location': {
            'type': 'Point',
            'coordinates': [_lng, _lat], // [lng, lat]
          },
        },
        'receiver': {
          'name': _receiverNameCtrl.text.trim(),
          'phone': _receiverPhoneCtrl.text.trim(),
        },
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm địa chỉ'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _field('Nhãn (vd: Nhà, Công ty)', _labelCtrl),
                const SizedBox(height: 12),
                _field('Địa chỉ (text)', _textCtrl),
                const SizedBox(height: 16),
                const Text('Toạ độ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _field('Paste link Google Maps', _mapsLinkCtrl)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _parseMapsLink,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('Parse'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _field('Lat', _latCtrl, TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Lng', _lngCtrl, TextInputType.number)),
                    const SizedBox(width: 8),
                    TextButton(onPressed: _applyManualCoords, child: const Text('Áp dụng')),
                  ],
                ),
                if (_lat != null && _lng != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(_lat!, _lng!),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.vifosa.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_lat!, _lng!),
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 36),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Người nhận', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _field('Tên người nhận', _receiverNameCtrl),
                const SizedBox(height: 8),
                _field('Số điện thoại', _receiverPhoneCtrl, TextInputType.phone),
              ],
            ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl,
      [TextInputType? keyboardType]) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}