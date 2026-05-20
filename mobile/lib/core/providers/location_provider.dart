// lib/core/providers/location_provider.dart
//
// Location priority:
//   1. Device GPS         — nếu trong bounding box VN
//   2. Địa chỉ mặc định  — từ /me/addresses (tọa độ đã lưu, đáng tin hơn GPS emulator)
//   3. IP geolocation     — ipwho.is, lấy vị trí thực của máy host khi dùng emulator
//   4. Fallback TP.HCM   — hardcoded last-resort

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

import '../network/api_endpoints.dart';
import '../network/dio_client.dart';

const _fallbackLat = 10.7994;
const _fallbackLng = 106.7116; // TP. Hồ Chí Minh

bool _isInVietnam(double lat, double lng) =>
    lat >= 8.18 && lat <= 23.39 && lng >= 102.14 && lng <= 109.46;

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);

  @override
  String toString() => 'LatLng($lat, $lng)';
}

// ── Step 1: GPS ───────────────────────────────────────────────────────────────

Future<LatLng?> _gpsLocation() async {
  try {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 8),
    );
    if (_isInVietnam(pos.latitude, pos.longitude)) {
      return LatLng(pos.latitude, pos.longitude);
    }
  } catch (_) {}
  return null;
}

// ── Step 2: Default saved address ────────────────────────────────────────────

Future<LatLng?> _savedAddressLocation(Ref ref) async {
  try {
    final client = ref.read(dioClientProvider);
    final res = await client.dio
        .get<Map<String, dynamic>>(ApiEndpoints.myAddresses)
        .timeout(const Duration(seconds: 5));
    final list = (res.data?['addresses'] as List<dynamic>?) ?? [];
    if (list.isEmpty) return null;

    final addr = list.firstWhere(
          (a) => (a as Map)['isDefault'] == true,
      orElse: () => list.first,
    ) as Map<String, dynamic>;

    final coords =
        (addr['address']?['location']?['coordinates'] as List<dynamic>?);
    if (coords == null || coords.length < 2) return null;

    final lng = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    if (_isInVietnam(lat, lng)) return LatLng(lat, lng);
  } catch (_) {}
  return null;
}

// ── Step 3: IP geolocation ────────────────────────────────────────────────────

Future<LatLng?> _ipLocation() async {
  try {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    final res = await dio.get<Map<String, dynamic>>('https://ipwho.is/');
    final body = res.data;
    if (body == null || body['success'] == false) return null;
    final lat = (body['latitude'] as num?)?.toDouble();
    final lng = (body['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (!_isInVietnam(lat, lng)) return null;
    return LatLng(lat, lng);
  } catch (_) {}
  return null;
}

// ── Provider ──────────────────────────────────────────────────────────────────

final locationProvider = FutureProvider<LatLng>((ref) async {
  final gps = await _gpsLocation();
  if (gps != null) {
    debugPrint('[Location] GPS: ${gps.lat}, ${gps.lng}');
    return gps;
  }

  final saved = await _savedAddressLocation(ref);
  if (saved != null) {
    debugPrint('[Location] Saved address: ${saved.lat}, ${saved.lng}');
    return saved;
  }

  final ip = await _ipLocation();
  if (ip != null) {
    debugPrint('[Location] IP: ${ip.lat}, ${ip.lng}');
    return ip;
  }

  debugPrint('[Location] Fallback TP.HCM');
  return const LatLng(_fallbackLat, _fallbackLng);
});
