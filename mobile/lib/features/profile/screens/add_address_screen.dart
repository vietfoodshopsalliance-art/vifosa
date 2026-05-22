// vifosa/mobile/lib/features/profile/screens/add_address_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../providers/profile_providers.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _labelCtrl         = TextEditingController();
  final _textCtrl          = TextEditingController();
  final _mapsLinkCtrl      = TextEditingController();
  final _receiverNameCtrl  = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();
  final _latCtrl           = TextEditingController();
  final _lngCtrl           = TextEditingController();

  double? _lat;
  double? _lng;
  bool _saving     = false;
  bool _gpsLoading = false;

  @override
  void dispose() {
    _labelCtrl.dispose();
    _textCtrl.dispose();
    _mapsLinkCtrl.dispose();
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _gpsLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần cấp quyền GPS để lấy vị trí')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _latCtrl.text = _lat!.toStringAsFixed(6);
        _lngCtrl.text = _lng!.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lấy được vị trí: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ── Parse Google Maps link ────────────────────────────────────────────────

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
    if (q != null) return (double.parse(q.group(1)!), double.parse(q.group(2)!));
    // Pattern 2: @lat,lng,
    final at = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),').firstMatch(url);
    if (at != null) return (double.parse(at.group(1)!), double.parse(at.group(2)!));
    // Pattern 3: /place/.../lat,lng
    final place = RegExp(r'place/[^/]+/(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (place != null) return (double.parse(place.group(1)!), double.parse(place.group(2)!));
    return null;
  }

  void _applyManualCoords() {
    final lat = double.tryParse(_latCtrl.text);
    final lng = double.tryParse(_lngCtrl.text);
    if (lat != null && lng != null) setState(() { _lat = lat; _lng = lng; });
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần chọn toạ độ trước')),
      );
      return;
    }
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần nhập địa chỉ')),
      );
      return;
    }
    if (_receiverNameCtrl.text.trim().isEmpty || _receiverPhoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần nhập thông tin người nhận')),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu thất bại: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                // ── Nhãn & địa chỉ text ───────────────────────────────────
                _field('Nhãn (vd: Nhà, Công ty)', _labelCtrl),
                const SizedBox(height: 12),
                _field('Địa chỉ (text)', _textCtrl),

                const SizedBox(height: 20),
                const Text('Toạ độ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                const Text(
                  'Chọn 1 trong 3 cách: GPS, paste link Google Maps, hoặc nhập thủ công.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),

                // ── GPS button ────────────────────────────────────────────
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: _gpsLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_gpsLoading ? 'Đang lấy vị trí...' : 'Dùng vị trí hiện tại (GPS)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _gpsLoading ? null : _getCurrentLocation,
                  ),
                ),

                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('hoặc', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Google Maps link ──────────────────────────────────────
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

                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('hoặc nhập thủ công', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Manual lat/lng ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(child: _field('Lat', _latCtrl, TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('Lng', _lngCtrl, TextInputType.number)),
                    const SizedBox(width: 8),
                    TextButton(onPressed: _applyManualCoords, child: const Text('Áp dụng')),
                  ],
                ),

                // ── Map preview ───────────────────────────────────────────
                if (_lat != null && _lng != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
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
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Toạ độ: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],

                // ── Người nhận ────────────────────────────────────────────
                const SizedBox(height: 20),
                const Text('Người nhận', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                _field('Tên người nhận', _receiverNameCtrl),
                const SizedBox(height: 8),
                _field('Số điện thoại', _receiverPhoneCtrl, TextInputType.phone),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _field(String hint, TextEditingController ctrl, [TextInputType? kbType]) =>
      TextField(
        controller: ctrl,
        keyboardType: kbType,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
