// vifosa/mobile/lib/features/profile/screens/add_address_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/address_model.dart';
import '../providers/profile_providers.dart';

enum _CoordMethod { address, gps, fullLink, shortLink }

class AddAddressScreen extends ConsumerStatefulWidget {
  final AddressModel? initialAddress;
  const AddAddressScreen({super.key, this.initialAddress});

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _labelCtrl         = TextEditingController();
  final _textCtrl          = TextEditingController();
  final _coordInputCtrl    = TextEditingController();
  final _receiverNameCtrl  = TextEditingController();
  final _receiverPhoneCtrl = TextEditingController();

  double? _lat;
  double? _lng;
  bool _saving       = false;
  bool _coordLoading = false;
  _CoordMethod _method = _CoordMethod.address;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAddress;
    if (a != null) {
      _labelCtrl.text         = a.label;
      _textCtrl.text          = a.text;
      _receiverNameCtrl.text  = a.receiverName;
      _receiverPhoneCtrl.text = a.receiverPhone;
      _lat = a.lat;
      _lng = a.lng;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _textCtrl.dispose();
    _coordInputCtrl.dispose();
    _receiverNameCtrl.dispose();
    _receiverPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Coordinate resolution ─────────────────────────────────────────────────

  Future<void> _resolveCoords() async {
    setState(() => _coordLoading = true);
    try {
      switch (_method) {
        case _CoordMethod.address:
          await _geocodeAddress();
        case _CoordMethod.gps:
          await _resolveGps();
        case _CoordMethod.fullLink:
          _parseFullLink(_coordInputCtrl.text.trim());
        case _CoordMethod.shortLink:
          await _resolveShortLink(_coordInputCtrl.text.trim());
      }
    } finally {
      if (mounted) setState(() => _coordLoading = false);
    }
  }

  Future<void> _geocodeAddress() async {
    final q = _textCtrl.text.trim();
    if (q.isEmpty) { _showSnack('Nhập địa chỉ trước'); return; }
    try {
      final res = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': q, 'format': 'json', 'limit': '1'},
        options: Options(headers: {'User-Agent': 'VifosaApp/1.0'}),
      );
      final list = res.data as List;
      if (list.isEmpty) { _showSnack('Không tìm thấy địa chỉ, thử cách khác'); return; }
      if (mounted) {
        setState(() {
          _lat = double.parse(list[0]['lat'] as String);
          _lng = double.parse(list[0]['lon'] as String);
        });
      }
    } catch (_) {
      _showSnack('Không thể tìm địa chỉ, thử cách khác');
    }
  }

  Future<void> _resolveGps() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnack('Cần cấp quyền GPS để lấy vị trí');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) setState(() { _lat = pos.latitude; _lng = pos.longitude; });
    } catch (e) {
      _showSnack('Không lấy được vị trí: $e');
    }
  }

  void _parseFullLink(String url) {
    if (url.isEmpty) { _showSnack('Paste link Google Maps trước'); return; }
    final latLng = _extractLatLng(url);
    if (latLng != null) {
      setState(() { _lat = latLng.$1; _lng = latLng.$2; });
    } else {
      _showSnack('Không tìm thấy toạ độ trong link này');
    }
  }

  Future<void> _resolveShortLink(String url) async {
    if (url.isEmpty) { _showSnack('Paste link rút gọn trước'); return; }
    try {
      final dio = Dio(BaseOptions(
        followRedirects: false,
        validateStatus: (_) => true,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      String current = url;
      for (int i = 0; i < 6; i++) {
        final res = await dio.get(current);
        final status = res.statusCode ?? 0;
        if (status >= 300 && status < 400) {
          final location = res.headers['location']?.first;
          if (location == null) break;
          current = Uri.parse(current).resolve(location).toString();
          final latLng = _extractLatLng(current);
          if (latLng != null) {
            if (mounted) setState(() { _lat = latLng.$1; _lng = latLng.$2; });
            return;
          }
        } else {
          break;
        }
      }
      final latLng = _extractLatLng(current);
      if (latLng != null) {
        if (mounted) setState(() { _lat = latLng.$1; _lng = latLng.$2; });
      } else {
        _showSnack('Không giải được toạ độ từ link này');
      }
    } catch (e) {
      _showSnack('Lỗi khi xử lý link: $e');
    }
  }

  (double, double)? _extractLatLng(String url) {
    // ?q=lat,lng  or  ll=lat,lng
    final q = RegExp(r'[?&](?:q|ll)=(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (q != null) return (double.parse(q.group(1)!), double.parse(q.group(2)!));
    // @lat,lng,zoom
    final at = RegExp(r'@(-?\d+\.?\d*),(-?\d+\.?\d*),').firstMatch(url);
    if (at != null) return (double.parse(at.group(1)!), double.parse(at.group(2)!));
    // /place/.../lat,lng
    final place = RegExp(r'place/[^/]+/(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(url);
    if (place != null) return (double.parse(place.group(1)!), double.parse(place.group(2)!));
    // !3d lat !4d lng  (encoded place URLs)
    final d3 = RegExp(r'!3d(-?\d+\.?\d*)').firstMatch(url);
    final d4 = RegExp(r'!4d(-?\d+\.?\d*)').firstMatch(url);
    if (d3 != null && d4 != null) {
      return (double.parse(d3.group(1)!), double.parse(d4.group(1)!));
    }
    return null;
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_lat == null || _lng == null) {
      _showSnack('Cần lấy toạ độ trước');
      return;
    }
    if (_textCtrl.text.trim().isEmpty) {
      _showSnack('Cần nhập địa chỉ');
      return;
    }
    if (_receiverNameCtrl.text.trim().isEmpty ||
        _receiverPhoneCtrl.text.trim().isEmpty) {
      _showSnack('Cần nhập thông tin người nhận');
      return;
    }

    setState(() => _saving = true);
    final payload = {
      'label': _labelCtrl.text.trim(),
      'address': {
        'text': _textCtrl.text.trim(),
        'location': {
          'type': 'Point',
          'coordinates': [_lng, _lat],
        },
      },
      'receiver': {
        'name': _receiverNameCtrl.text.trim(),
        'phone': _receiverPhoneCtrl.text.trim(),
      },
    };
    try {
      final notifier = ref.read(addressNotifierProvider.notifier);
      if (widget.initialAddress != null) {
        await notifier.update(widget.initialAddress!.id, payload);
      } else {
        await notifier.add(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Lưu thất bại: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialAddress != null ? 'Sửa địa chỉ' : 'Thêm địa chỉ'),
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
                // ── Nhãn & địa chỉ ────────────────────────────────────────
                _field('Nhãn (vd: Nhà, Công ty)', _labelCtrl),
                const SizedBox(height: 12),
                _field('Địa chỉ (mô tả để giao hàng)', _textCtrl),

                const SizedBox(height: 24),

                // ── Toạ độ ────────────────────────────────────────────────
                const Text(
                  'Toạ độ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 10),

                _MethodSelector(
                  selected: _method,
                  onChanged: (m) => setState(() {
                    _method = m;
                    _coordInputCtrl.clear();
                  }),
                ),

                const SizedBox(height: 12),

                _buildMethodInput(),

                const SizedBox(height: 12),

                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: _coordLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.location_searching),
                    label: Text(
                        _coordLoading ? 'Đang lấy toạ độ...' : 'Lấy toạ độ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _coordLoading ? null : _resolveCoords,
                  ),
                ),

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
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                const SizedBox(height: 24),
                const Text(
                  'Người nhận',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 8),
                _field('Tên người nhận', _receiverNameCtrl),
                const SizedBox(height: 8),
                _field('Số điện thoại', _receiverPhoneCtrl,
                    TextInputType.phone),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildMethodInput() {
    switch (_method) {
      case _CoordMethod.address:
        return const Text(
          'Dùng nội dung "Địa chỉ" đã nhập ở trên để tìm kiếm toạ độ.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      case _CoordMethod.gps:
        return const Text(
          'Sẽ dùng vị trí GPS hiện tại của thiết bị.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        );
      case _CoordMethod.fullLink:
        return _field(
            'Paste link Google Maps (chứa lat/lng)', _coordInputCtrl);
      case _CoordMethod.shortLink:
        return _field(
            'Paste link rút gọn (maps.app.goo.gl/...)', _coordInputCtrl);
    }
  }

  Widget _field(String hint, TextEditingController ctrl,
          [TextInputType? kbType]) =>
      TextField(
        controller: ctrl,
        keyboardType: kbType,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ── Method Selector ───────────────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  final _CoordMethod selected;
  final ValueChanged<_CoordMethod> onChanged;

  const _MethodSelector({required this.selected, required this.onChanged});

  static const _items = [
    (_CoordMethod.address, Icons.search, 'Địa chỉ'),
    (_CoordMethod.gps, Icons.my_location, 'GPS'),
    (_CoordMethod.fullLink, Icons.link, 'Link Maps'),
    (_CoordMethod.shortLink, Icons.open_in_new, 'Link rút gọn'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items.map((item) {
        final isSelected = selected == item.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(item.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.orange
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.$2,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
