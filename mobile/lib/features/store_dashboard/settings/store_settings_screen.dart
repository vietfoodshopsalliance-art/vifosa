// lib/features/store_dashboard/settings/store_settings_screen.dart

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Multiple cover images: existing URLs + new local files (null = keep existing)
  List<String> _coverImageUrls = [];
  List<XFile?> _coverImageFiles = [];
  XFile? _newAvatar;

  // Notification settings
  bool _bellEnabled = true;

  // Open hours
  Map<String, DayHours> _openHours = {};

  // Emergency close
  bool _emergencyClosed = false;

  // Location
  double? _lat;
  double? _lng;
  final _mapsCoordCtrl = TextEditingController();
  final _mapsShareCtrl = TextEditingController();
  bool _geocoding = false;

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
    _loadBellPref();
  }

  Future<void> _loadBellPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _bellEnabled = prefs.getBool('bell_enabled') ?? true);
    }
  }

  Future<void> _setBellEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bell_enabled', v);
    if (mounted) setState(() => _bellEnabled = v);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _mapsCoordCtrl.dispose();
    _mapsShareCtrl.dispose();
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

        // Multiple cover images
        final rawCovers = d['coverImages'] as List? ?? [];
        _coverImageUrls = rawCovers.whereType<String>().toList();
        // If no array yet but legacy single cover exists, pre-populate
        if (_coverImageUrls.isEmpty && _coverUrl != null && _coverUrl!.isNotEmpty) {
          _coverImageUrls = [_coverUrl!];
        }
        _coverImageFiles = List.filled(_coverImageUrls.length, null);

        _emergencyClosed = d['emergencyClosed'] as bool? ?? false;

        final pm = d['paymentMethods'] as Map? ?? {};
        _pmBankTransfer = pm['bankTransfer'] as bool? ?? false;
        _pmCod = pm['cod'] as bool? ?? false;
        _pmFiftyFifty = pm['fiftyFifty'] as bool? ?? false;

        final ba = d['bankAccount'] as Map? ?? {};
        final bankFromDb = ba['bank'] as String?;
        _selectedBank = _banks.contains(bankFromDb) ? bankFromDb : null;
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

    } catch (e) {
      if (mounted) {
        final is403 = e is DioException && e.response?.statusCode == 403;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(is403
                ? 'Bạn không có quyền truy cập quán này'
                : 'Không tải được cài đặt: $e'),
          ),
        );
        if (is403) Navigator.of(context).pop();
      }
      setState(() => _initialLoaded = true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final imageService = ref.read(imageServiceProvider);
      String? avatarUrl = _avatarUrl;
      if (_newAvatar != null) {
        final result = await imageService.uploadFile(
          File(_newAvatar!.path),
          context: ImageUploadContext.storeAvatar,
        );
        avatarUrl = result.url;
      }

      // Upload new cover images (slots where user picked a new file)
      final finalCoverUrls = <String>[];
      for (int i = 0; i < _coverImageUrls.length; i++) {
        final newFile = i < _coverImageFiles.length ? _coverImageFiles[i] : null;
        if (newFile != null) {
          final result = await imageService.uploadFile(
            File(newFile.path),
            context: ImageUploadContext.storeCover,
          );
          finalCoverUrls.add(result.url);
        } else {
          finalCoverUrls.add(_coverImageUrls[i]);
        }
      }

      await DioClient.instance.patch(
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
          // Primary cover = first in array (also update legacy field for compat)
          if (finalCoverUrls.isNotEmpty) 'coverImage': finalCoverUrls.first,
          'coverImages': finalCoverUrls,
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
        String msg = 'Lỗi khi lưu cài đặt';
        if (e is DioException) {
          final body = e.response?.data;
          if (body is Map && body['error'] != null) {
            msg = body['error'].toString();
          } else if (body is Map && body['message'] != null) {
            msg = body['message'].toString();
          } else {
            msg = 'Lỗi ${e.response?.statusCode ?? ""}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  (double, double)? _extractCoords(String text) {
    final r1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    final r2 = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)');
    final r3 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    final match = r1.firstMatch(text) ?? r2.firstMatch(text) ?? r3.firstMatch(text);
    if (match == null) return null;
    return (double.parse(match.group(1)!), double.parse(match.group(2)!));
  }

  Future<(double, double)?> _followShareLink(String url) async {
    try {
      final client = Dio(BaseOptions(
        followRedirects: true,
        maxRedirects: 5,
        receiveTimeout: const Duration(seconds: 10),
        connectTimeout: const Duration(seconds: 10),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; vifosa-app/1.0)'},
      ));
      final res = await client.get(url);
      return _extractCoords(res.realUri.toString());
    } on DioException catch (e) {
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
      final addr = _addressCtrl.text.trim();
      if (addr.isNotEmpty) {
        try {
          final client = Dio();
          final res = await client.get(
            'https://nominatim.openstreetmap.org/search',
            queryParameters: {
              'q': addr,
              'format': 'json',
              'limit': '1',
              'countrycodes': 'vn',
            },
            options: Options(headers: {'User-Agent': 'vifosa-app/1.0 (contact@vifosa.vn)'}),
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
        } on DioException catch (e) {
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

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (file == null) return;
    if (isAvatar) {
      setState(() => _newAvatar = file);
    }
  }

  Future<void> _pickCoverImage(int index) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      if (index < _coverImageFiles.length) {
        _coverImageFiles[index] = file;
      }
    });
  }

  void _addCoverSlot() {
    if (_coverImageUrls.length >= 5) return;
    setState(() {
      _coverImageUrls.add('');
      _coverImageFiles.add(null);
    });
    _pickCoverImage(_coverImageUrls.length - 1);
  }

  void _removeCoverSlot(int index) {
    setState(() {
      _coverImageUrls.removeAt(index);
      _coverImageFiles.removeAt(index);
    });
  }

  void _moveCoverUp(int index) {
    if (index <= 0) return;
    setState(() {
      final url = _coverImageUrls.removeAt(index);
      _coverImageUrls.insert(index - 1, url);
      final file = _coverImageFiles.removeAt(index);
      _coverImageFiles.insert(index - 1, file);
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
            const _SectionHeader('Thông báo'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Chuông thông báo đơn mới'),
              subtitle: Text(_bellEnabled ? 'Bật — nghe tiếng chuông khi có đơn' : 'Tắt'),
              value: _bellEnabled,
              onChanged: _setBellEnabled,
            ),

            const SizedBox(height: 20),
            const _SectionHeader('Thông tin quán'),
            // Avatar
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
              ],
            ),
            const SizedBox(height: 12),

            // Multiple cover images
            const Text('Ảnh bìa (tối đa 5, ảnh đầu hiển thị trước)',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            ..._coverImageUrls.asMap().entries.map((entry) {
              final i = entry.key;
              final url = entry.value;
              final file = i < _coverImageFiles.length ? _coverImageFiles[i] : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickCoverImage(i),
                      child: Container(
                        width: 100,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade200,
                          image: file != null
                              ? DecorationImage(
                                  image: FileImage(File(file.path)),
                                  fit: BoxFit.cover)
                              : (url.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(url),
                                      fit: BoxFit.cover)
                                  : null),
                        ),
                        child: (file == null && url.isEmpty)
                            ? const Icon(Icons.add_photo_alternate_outlined,
                                color: Colors.grey, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('Ảnh chính',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange)),
                          ),
                        if (i > 0)
                          TextButton.icon(
                            onPressed: () => _moveCoverUp(i),
                            icon: const Icon(Icons.arrow_upward, size: 14),
                            label: const Text('Lên trước', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () => _removeCoverSlot(i),
                          icon: const Icon(Icons.delete_outline, size: 14,
                              color: Colors.red),
                          label: const Text('Xoá',
                              style: TextStyle(fontSize: 12, color: Colors.red)),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            if (_coverImageUrls.length < 5)
              OutlinedButton.icon(
                onPressed: _addCoverSlot,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Thêm ảnh bìa'),
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
                  labelText: 'Địa chỉ (tuỳ chọn)', border: OutlineInputBorder()),
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
                            child: CircularProgressIndicator(strokeWidth: 2))
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
