// lib/features/store_dashboard/settings/store_settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/image_service.dart' show ImageUploadContext, imageServiceProvider;
import 'open_hours_editor.dart';

// ─── Vietnamese banks list ────────────────────────────────────────────────────

// Mapping key ngày → dayOfWeek index (0=Sun … 6=Sat, theo chuẩn backend)
const _dayOfWeekMap = <String, int>{
  'sun': 0, 'mon': 1, 'tue': 2, 'wed': 3, 'thu': 4, 'fri': 5, 'sat': 6,
};

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

// ─── Screen ───────────────────────────────────────────────────────────────────

class StoreSettingsScreen extends ConsumerStatefulWidget {
  final String storeId;
  const StoreSettingsScreen({super.key, required this.storeId});

  @override
  ConsumerState<StoreSettingsScreen> createState() =>
      _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends ConsumerState<StoreSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Info
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _avatarUrl;
  String? _coverUrl;
  XFile? _newAvatar;
  XFile? _newCover;

  // Open hours
  Map<String, DayHours> _openHours = {};

  // Emergency close
  bool _emergencyClosed = false;

  // Location
  double? _lat;
  double? _lng;
  final _mapsCtrl = TextEditingController();

  // Payment methods
  bool _pmBankTransfer = true;
  bool _pmCod = false;
  bool _pmFiftyFifty = false;

  // Bank account
  String? _selectedBank;
  final _bankNoCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();

  // Order config
  final _autoCancelCtrl = TextEditingController(text: '15');
  final _autoConfirmCtrl = TextEditingController(text: '0');

  // Ship fee
  final _shipACtrl = TextEditingController(text: '12000');
  final _shipBCtrl = TextEditingController(text: '5000');
  final _shipCCtrl = TextEditingController(text: '0');

  bool _loading = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _mapsCtrl.dispose();
    _bankNoCtrl.dispose();
    _bankNameCtrl.dispose();
    _autoCancelCtrl.dispose();
    _autoConfirmCtrl.dispose();
    _shipACtrl.dispose();
    _shipBCtrl.dispose();
    _shipCCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final res = await DioClient.instance.get(ApiEndpoints.myStoreById(widget.storeId));
      final raw = res.data as Map<String, dynamic>;
      final d = (raw['store'] ?? raw) as Map<String, dynamic>;
            debugPrint('=== LOAD store data: $d');
      
            setState(() {
        _nameCtrl.text = d['name'] as String? ?? '';
        _descCtrl.text = d['description'] as String? ?? '';
        final addr = d['address'] as Map? ?? {};
        _addressCtrl.text = addr['text'] as String? ?? '';
        final coords = (addr['location'] as Map?)?['coordinates'] as List?;
        if (coords != null && coords.length >= 2) {
          _lng = (coords[0] as num).toDouble();
          _lat = (coords[1] as num).toDouble();
        }
        _phoneCtrl.text = d['phone'] as String? ?? '';

        // Fix 1: đúng key
        _avatarUrl = d['avatarImage'] as String?;
        _coverUrl = d['coverImage'] as String?;

        _emergencyClosed = d['emergencyClosed'] as bool? ?? false;

        final pm = d['paymentMethods'] as Map? ?? {};
        _pmBankTransfer = pm['bankTransfer'] as bool? ?? false;
        _pmCod = pm['cod'] as bool? ?? false;
        _pmFiftyFifty = pm['fiftyFifty'] as bool? ?? false;

        final ba = d['bankAccount'] as Map? ?? {};
        _selectedBank = ba['bank'] as String?;
        _bankNoCtrl.text = ba['number'] as String? ?? '';
        _bankNameCtrl.text = (ba['name'] ?? ba['holder']) as String? ?? '';

        // Fix 2: đọc mảng openingHours theo dayOfWeek
        final ohList = d['openingHours'] as List? ?? [];
        const dayKeys = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
        final ohMap = <String, dynamic>{};
        for (final item in ohList) {
          final dow = (item as Map)['dayOfWeek'] as int? ?? 0;
          if (dow < dayKeys.length) ohMap[dayKeys[dow]] = item;
        }
        _openHours = {
          for (final key in dayKeys)
            key: DayHours.fromJson(ohMap[key] as Map<String, dynamic>?)
        };

        final sf = d['shipFeeFormula'] as Map? ?? (d['shipFee'] as Map? ?? {});
        _shipACtrl.text = (sf['a'] ?? 12000).toString();
        _shipBCtrl.text = (sf['b'] ?? 5000).toString();
        _shipCCtrl.text = (sf['c'] ?? 0).toString();
        _autoCancelCtrl.text = (d['autoCancelMinutes'] ?? 15).toString();
        _autoConfirmCtrl.text = (d['autoConfirmMinutes'] ?? 0).toString();

        _initialLoaded = true;
      });

    } catch (_) {
      setState(() => _initialLoaded = true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final imageService = ref.read(imageServiceProvider);
      String? avatarUrl = _avatarUrl;
      String? coverUrl = _coverUrl;
      if (_newAvatar != null) {
        final result = await imageService.uploadFile(
          File(_newAvatar!.path),
          context: ImageUploadContext.storeAvatar,
        );
        avatarUrl = result.url;
      }
      if (_newCover != null) {
        final result = await imageService.uploadFile(
          File(_newCover!.path),
          context: ImageUploadContext.storeCover,
        );
        coverUrl = result.url;
      }

      final dio = ref.read(dioClientProvider);

      await dio.dio.patch(
        ApiEndpoints.myStoreById(widget.storeId),
        data: {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          // Chỉ gửi address khi có toạ độ (location là required trong schema)
          if (_lat != null && _lng != null)
            'address': {
              'text': _addressCtrl.text.trim(),
              'location': {
                'type': 'Point',
                'coordinates': [_lng, _lat],
              },
            },
          if (avatarUrl != null) 'avatarImage': avatarUrl,
          if (coverUrl != null) 'coverImage': coverUrl,
          // Thêm dayOfWeek vào mỗi entry (backend required: true)
          'openingHours': _openHours.entries.map((e) => {
            'dayOfWeek': _dayOfWeekMap[e.key] ?? 0,
            ...e.value.toJson(),
          }).toList(),
          'paymentMethods': {
            'bankTransfer': _pmBankTransfer,
            'cod': _pmCod,
            'fiftyFifty': _pmFiftyFifty,
          },
          'bankAccount': {
            'bank': _selectedBank ?? '',
            'number': _bankNoCtrl.text.trim(),
            'holder': _bankNameCtrl.text.trim(),
          },
          'shipFeeFormula': {
            'a': int.tryParse(_shipACtrl.text) ?? 12000,
            'b': int.tryParse(_shipBCtrl.text) ?? 5000,
            'c': int.tryParse(_shipCCtrl.text) ?? 0,
          },
          'autoCancelMinutes': int.tryParse(_autoCancelCtrl.text) ?? 15,
          'autoConfirmMinutes': int.tryParse(_autoConfirmCtrl.text) ?? 0,
        },
      );


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu cài đặt')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleEmergencyClose(bool value) async {
    if (value) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Đóng cửa khẩn cấp'),
          content: const Text(
              'Đóng cửa khẩn cấp sẽ ẩn quán khỏi ứng dụng và không nhận đơn mới. Xác nhận?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    try {
      await DioClient.instance.patch(
        ApiEndpoints.myStoreEmergencyClose(widget.storeId),
        data: {'close': value},
      );
      setState(() => _emergencyClosed = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _useGps() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng bật GPS')));
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quyền truy cập GPS bị từ chối')));
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lấy được vị trí: $e')));
    }
  }

  void _parseMapsLink() {
    final text = _mapsCtrl.text;
    final r1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final r2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final r3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = r1.firstMatch(text) ?? r2.firstMatch(text) ?? r3.firstMatch(text);
    if (match != null) {
      setState(() {
        _lat = double.parse(match.group(1)!);
        _lng = double.parse(match.group(2)!);
      });
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không tìm thấy toạ độ trong link')));
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() {
      if (isAvatar) {
        _newAvatar = file;
      } else {
        _newCover = file;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final a = int.tryParse(_shipACtrl.text) ?? 12000;
    final b = int.tryParse(_shipBCtrl.text) ?? 5000;
    final c = int.tryParse(_shipCCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt quán')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader('Thông tin quán'),
            // Avatar & Cover
            Row(
              children: [
                _ImagePickerTile(
                  label: 'Ảnh đại diện',
                  url: _avatarUrl,
                  file: _newAvatar != null ? File(_newAvatar!.path) : null,
                  size: 80,
                  circular: true,
                  onTap: () => _pickImage(true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ImagePickerTile(
                    label: 'Ảnh bìa',
                    url: _coverUrl,
                    file: _newCover != null ? File(_newCover!.path) : null,
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
                  labelText: 'Tên quán *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên quán'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Mô tả', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                  labelText: 'Địa chỉ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useGps,
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Dùng GPS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mapsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Paste link Google Maps (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  width: 64,
                  child: OutlinedButton(
                    onPressed: _parseMapsLink,
                    child: const Text('Lấy'),
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
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'SĐT quán (tuỳ chọn)',
                  border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),
            const _SectionHeader('Giờ mở cửa'),
            OpenHoursEditor(
              initialValue: _openHours,
              onChanged: (v) => setState(() => _openHours = v),
            ),

            const SizedBox(height: 20),
            const _SectionHeader('Đóng cửa khẩn cấp'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Đóng cửa khẩn cấp'),
              subtitle: Text(_emergencyClosed
                  ? 'Quán đang ẩn – không nhận đơn'
                  : 'Quán đang hoạt động bình thường'),
              value: _emergencyClosed,
              activeThumbColor: Colors.red,
              onChanged: _toggleEmergencyClose,
            ),

            const SizedBox(height: 20),
            const _SectionHeader('Phương thức thanh toán nhận'),
            _PaymentSwitch(
              label: 'Chuyển khoản',
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

            const SizedBox(height: 20),
            const _SectionHeader('Tài khoản ngân hàng quán'),
            
              DropdownButtonFormField<String>(
              initialValue: _selectedBank,
              decoration: const InputDecoration(
                  labelText: 'Ngân hàng *',
                  border: OutlineInputBorder()),
              
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBank = v),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Vui lòng chọn ngân hàng' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bankNoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Số TK *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập số TK'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bankNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Tên chủ TK *',
                  border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tên chủ TK'
                  : null,
            ),

            const SizedBox(height: 20),
            const _SectionHeader('Cấu hình đơn hàng'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _autoCancelCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Auto-cancel (phút)',
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
                      labelText: 'Auto-confirm (phút)',
                      border: OutlineInputBorder(),
                      helperText: '0 = tắt',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Công thức phí ship',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(child: _ShipFeeField(ctrl: _shipACtrl, label: 'A (cố định, đ)')),
                const SizedBox(width: 8),
                Expanded(child: _ShipFeeField(ctrl: _shipBCtrl, label: 'B (đ/km)')),
                const SizedBox(width: 8),
                Expanded(child: _ShipFeeField(ctrl: _shipCCtrl, label: 'C (% cao điểm)')),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              'Preview: ($a + $b × km) × (1 + $c%)',
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  fontSize: 12),
            ),

            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu cài đặt'),
            ),
            const SizedBox(height: 24),
          ],
        ),
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
      {required this.label,
      required this.value,
      required this.onChanged});

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
  final String? url;
  final File? file;
  final double size;
  final bool circular;
  final VoidCallback onTap;

  const _ImagePickerTile({
    required this.label,
    this.url,
    this.file,
    required this.size,
    required this.circular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (file != null) {
      image = FileImage(file!);
    } else if (url != null) {
      image = NetworkImage(url!);
    }

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
