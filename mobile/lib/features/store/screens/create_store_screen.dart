// lib/features/store/screens/create_store_screen.dart

import 'dart:io';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/image_service.dart'
    show ImageUploadContext, imageServiceProvider;
import '../providers/store_providers.dart';

const _dayLabels = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

const _banks = [
  'ACB',
  'Agribank',
  'BIDV',
  'HDBank',
  'MB Bank',
  'MSB',
  'OCB',
  'Sacombank',
  'SeABank',
  'SHB',
  'Techcombank',
  'TPBank',
  'VIB',
  'VietinBank',
  'Vietcombank',
  'VPBank',
];

class CreateStoreScreen extends ConsumerStatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  ConsumerState<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends ConsumerState<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();

  // Basic info
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Images
  XFile? _newAvatar;
  XFile? _newCover;

  // Location
  final _addrCtrl = TextEditingController();
  final _mapsCoordCtrl = TextEditingController();
  final _mapsShareCtrl = TextEditingController();
  double? _lat, _lng;
  bool _geocoding = false;

  // Bank
  String? _selectedBank;
  final _bankNoCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();

  // Opening hours
  final List<Map<String, dynamic>> _hours = List.generate(
    7,
    (i) => {
      'dayOfWeek': i,
      'open': '08:00',
      'close': '22:00',
      'isClosed': false,
    },
  );

  // Payment methods
  bool _pmBankTransfer = true;
  bool _pmCod = false;
  bool _pmFiftyFifty = false;

  // Order config
  final _autoCancelCtrl = TextEditingController(text: '15');
  final _autoConfirmCtrl = TextEditingController(text: '0');

  // Ship fee
  final _shipACtrl = TextEditingController(text: '12000');
  final _shipBCtrl = TextEditingController(text: '5000');
  final _shipCCtrl = TextEditingController(text: '0');

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _mapsCoordCtrl.dispose();
    _mapsShareCtrl.dispose();
    _bankNoCtrl.dispose();
    _bankHolderCtrl.dispose();
    _autoCancelCtrl.dispose();
    _autoConfirmCtrl.dispose();
    _shipACtrl.dispose();
    _shipBCtrl.dispose();
    _shipCCtrl.dispose();
    super.dispose();
  }

  // ─── Image picker ─────────────────────────────────────────────────────────

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() {
      if (isAvatar) {
        _newAvatar = file;
      } else {
        _newCover = file;
      }
    });
  }

  // ─── Coordinate extraction & geocoding ───────────────────────────────────

  (double, double)? _extractCoords(String text) {
    final r1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final r2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final r3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final match =
        r1.firstMatch(text) ?? r2.firstMatch(text) ?? r3.firstMatch(text);
    if (match == null) return null;
    return (double.parse(match.group(1)!), double.parse(match.group(2)!));
  }

  Future<(double, double)?> _followShareLink(String url) async {
    try {
      final client = dio_pkg.Dio(dio_pkg.BaseOptions(
        followRedirects: true,
        maxRedirects: 5,
        receiveTimeout: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; vifosa-app/1.0)'},
      ));
      final res = await client.get(url);
      return _extractCoords(res.realUri.toString());
    } on dio_pkg.DioException catch (e) {
      final location = e.response?.headers.value('location');
      if (location != null) return _extractCoords(location);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _getCoords() async {
    setState(() => _geocoding = true);
    try {
      // 1. Ưu tiên địa chỉ text → Nominatim
      final addr = _addrCtrl.text.trim();
      if (addr.isNotEmpty) {
        try {
          final client = dio_pkg.Dio();
          final res = await client.get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': addr,
              'format': 'json',
              'limit': '1',
              'countrycodes': 'vn',
            },
            options: dio_pkg.Options(
                headers: {'User-Agent': 'vifosa-app/1.0 (contact@vifosa.vn)'}),
          );
          final list = res.data as List;
          if (list.isNotEmpty) {
            final item = list[0] as Map<String, dynamic>;
            setState(() {
              _lat = double.parse(item['lat'] as String);
              _lng = double.parse(item['lon'] as String);
            });
            return;
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Không tìm thấy toạ độ cho địa chỉ này')));
          }
          return;
        } on dio_pkg.DioException catch (e) {
          final status = e.response?.statusCode;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                status == 503
                    ? 'Dịch vụ tìm địa chỉ đang quá tải, thử lại sau hoặc dán link Google Maps bên dưới.'
                    : 'Không tìm được toạ độ từ địa chỉ (lỗi $status). Hãy dán link Google Maps.',
              ),
            ));
          }
          return;
        }
      }

      // 2. Link Google Maps có lat/lng → parse trực tiếp
      final coordLink = _mapsCoordCtrl.text.trim();
      if (coordLink.isNotEmpty) {
        final coords = _extractCoords(coordLink);
        if (coords != null) {
          setState(() {
            _lat = coords.$1;
            _lng = coords.$2;
          });
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Không tìm thấy toạ độ trong link này')));
        }
        return;
      }

      // 3. Link Google Maps share → follow redirect
      final shareLink = _mapsShareCtrl.text.trim();
      if (shareLink.isNotEmpty) {
        final coords = await _followShareLink(shareLink);
        if (coords != null) {
          setState(() {
            _lat = coords.$1;
            _lng = coords.$2;
          });
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Không tìm thấy toạ độ trong link share')));
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nhập địa chỉ hoặc paste link Google Maps')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lấy tọa độ: $e')));
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _useGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật GPS')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền truy cập GPS bị từ chối')));
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Không lấy được vị trí: $e')));
    }
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_pmBankTransfer && !_pmCod && !_pmFiftyFifty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chọn tối thiểu 1 phương thức thanh toán')));
      return;
    }
    setState(() => _saving = true);
    try {
      final store =
          await ref.read(storeNotifierProvider.notifier).createStore({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_lat != null && _lng != null)
          'address': {
            'text': _addrCtrl.text.trim(),
            'location': {
              'type': 'Point',
              'coordinates': [_lng, _lat],
            },
          },
        'openingHours': _hours,
        'bankAccount': {
          if (_selectedBank != null) 'bank': _selectedBank,
          'number': _bankNoCtrl.text.trim(),
          'holder': _bankHolderCtrl.text.trim(),
        },
        'paymentMethods': {
          'bankTransfer': _pmBankTransfer,
          'cod': _pmCod,
          'fiftyFifty': _pmFiftyFifty,
        },
        'shipFeeFormula': {
          'a': int.tryParse(_shipACtrl.text) ?? 12000,
          'b': int.tryParse(_shipBCtrl.text) ?? 5000,
          'c': int.tryParse(_shipCCtrl.text) ?? 0,
        },
        'autoCancelMinutes': int.tryParse(_autoCancelCtrl.text) ?? 15,
        'autoConfirmMinutes': int.tryParse(_autoConfirmCtrl.text) ?? 0,
      });

      // Upload images after store is created
      if (_newAvatar != null || _newCover != null) {
        final imageService = ref.read(imageServiceProvider);
        if (_newAvatar != null) {
          final result = await imageService.uploadFile(
            File(_newAvatar!.path),
            context: ImageUploadContext.storeAvatar,
          );
          await ref
              .read(storeNotifierProvider.notifier)
              .updateStore(store.id, {'avatarImage': result.url});
        }
        if (_newCover != null) {
          final result = await imageService.uploadFile(
            File(_newCover!.path),
            context: ImageUploadContext.storeCover,
          );
          await ref
              .read(storeNotifierProvider.notifier)
              .updateStore(store.id, {'coverImage': result.url});
        }
      }

      if (mounted) {
        context.go('/store-dashboard/${store.id}/orders');
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Lỗi tạo quán: $e';
        if (e is dio_pkg.DioException && e.response?.statusCode == 403) {
          final data = e.response?.data;
          msg = data is Map ? (data['error'] as String? ?? msg) : msg;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final a = int.tryParse(_shipACtrl.text) ?? 12000;
    final b = int.tryParse(_shipBCtrl.text) ?? 5000;
    final c = int.tryParse(_shipCCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo quán mới')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Thông tin cơ bản ───────────────────────────────────
                  const _SectionHeader('Thông tin cơ bản'),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ImagePickerTile(
                        label: 'Ảnh đại diện',
                        file: _newAvatar != null
                            ? File(_newAvatar!.path)
                            : null,
                        size: 80,
                        circular: true,
                        onTap: () => _pickImage(true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ImagePickerTile(
                          label: 'Ảnh bìa',
                          file: _newCover != null
                              ? File(_newCover!.path)
                              : null,
                          size: 80,
                          circular: false,
                          onTap: () => _pickImage(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên quán *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên quán'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'SĐT quán (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // ── Địa chỉ & Vị trí ──────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Địa chỉ & Vị trí'),

                  TextFormField(
                    controller: _addrCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _mapsCoordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link Google Maps có toạ độ (tuỳ chọn)',
                      hintText: 'https://maps.google.com/...@10.77,106.70...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _mapsShareCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Link Google Maps share (tuỳ chọn)',
                      hintText: 'https://maps.app.goo.gl/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _geocoding ? null : _getCoords,
                          icon: _geocoding
                              ? const SizedBox.square(
                                  dimension: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.location_searching, size: 16),
                          label: const Text('Lấy toạ độ'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _useGps,
                          icon: const Icon(Icons.my_location, size: 16),
                          label: const Text('GPS hiện tại'),
                        ),
                      ),
                    ],
                  ),
                  if (_lat != null && _lng != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Toạ độ: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
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

                  // ── Giờ mở cửa ────────────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Giờ mở cửa'),
                  ..._hours.asMap().entries.map((e) {
                    final i = e.key;
                    final h = e.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 32,
                          child: Text(_dayLabels[h['dayOfWeek']],
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ),
                        Checkbox(
                          value: !h['isClosed'],
                          onChanged: (v) => setState(
                              () => _hours[i]['isClosed'] = !(v ?? true)),
                        ),
                        Expanded(
                          child: Row(children: [
                            _timeField(h['open'], h['isClosed'],
                                (v) => setState(() => _hours[i]['open'] = v)),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('→'),
                            ),
                            _timeField(h['close'], h['isClosed'],
                                (v) =>
                                    setState(() => _hours[i]['close'] = v)),
                          ]),
                        ),
                      ]),
                    );
                  }),

                  // ── Phương thức thanh toán ─────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Phương thức thanh toán *'),
                  _PaymentSwitch(
                    label: 'Chuyển khoản ngân hàng',
                    value: _pmBankTransfer,
                    onChanged: (v) {
                      if (!v && !_pmCod && !_pmFiftyFifty) return;
                      setState(() => _pmBankTransfer = v);
                    },
                  ),
                  _PaymentSwitch(
                    label: 'COD (tiền mặt)',
                    value: _pmCod,
                    onChanged: (v) {
                      if (!v && !_pmBankTransfer && !_pmFiftyFifty) return;
                      setState(() => _pmCod = v);
                    },
                  ),
                  _PaymentSwitch(
                    label: '50/50',
                    value: _pmFiftyFifty,
                    onChanged: (v) {
                      if (!v && !_pmBankTransfer && !_pmCod) return;
                      setState(() => _pmFiftyFifty = v);
                    },
                  ),

                  // ── Tài khoản ngân hàng ────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Tài khoản ngân hàng'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Ngân hàng',
                      border: OutlineInputBorder(),
                    ),
                    items: _banks
                        .map((b) =>
                            DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBank = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bankNoCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số tài khoản',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bankHolderCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên chủ tài khoản',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  // ── Cấu hình đơn hàng ──────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Cấu hình đơn hàng'),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _autoCancelCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tự động từ chối (phút)',
                            border: OutlineInputBorder(),
                            helperText: 'min 5',
                          ),
                          validator: (v) {
                            final n = int.tryParse(v ?? '');
                            if (n == null || n < 5) return 'Tối thiểu 5 phút';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _autoConfirmCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tự động xác nhận (phút)',
                            border: OutlineInputBorder(),
                            helperText: '0 = tắt',
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Phí ship ───────────────────────────────────────────
                  const SizedBox(height: 20),
                  const _SectionHeader('Công thức phí ship'),
                  Row(
                    children: [
                      Expanded(
                          child: _ShipFeeField(
                              ctrl: _shipACtrl, label: 'A (cố định, đ)')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _ShipFeeField(
                              ctrl: _shipBCtrl, label: 'B (đ/km)')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _ShipFeeField(
                              ctrl: _shipCCtrl, label: 'C (% cao điểm)')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview: ($a + $b × km) × (1 + $c%)',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child:
                          Text('Tạo quán', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _timeField(
      String value, bool disabled, void Function(String) onChanged) {
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
          border: Border.all(
              color: disabled ? Colors.grey.shade300 : Colors.grey),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(value,
            style: TextStyle(
                color: disabled ? Colors.grey.shade400 : Colors.black)),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PaymentSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PaymentSwitch(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ShipFeeField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  const _ShipFeeField({required this.ctrl, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
    );
  }
}

class _ImagePickerTile extends StatelessWidget {
  final String label;
  final File? file;
  final double size;
  final bool circular;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.label,
    this.file,
    required this.size,
    required this.circular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image =
        file != null ? FileImage(file!) : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular ? null : BorderRadius.circular(8),
              color: Colors.grey.shade200,
              image: image != null
                  ? DecorationImage(image: image, fit: BoxFit.cover)
                  : null,
            ),
            child: image == null
                ? const Icon(Icons.camera_alt_outlined,
                    color: Colors.grey, size: 28)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
