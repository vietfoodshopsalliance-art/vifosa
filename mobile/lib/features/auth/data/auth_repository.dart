import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> register({
    required String username,
    required String nickname,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post(ApiEndpoints.register, data: {
      'username':    username,
      'nickname':    nickname,
      'email':       email,
      'phone':       phone,
      'password':    password,
      'tosAccepted': true,
      'tosVersion':  '1.0',
    });
    final payload = res.data['data'] as Map<String, dynamic>;
    await _saveTokens(payload);
    return payload;
  }

  Future<Map<String, dynamic>> login({
    required String credential,
    required String password,
  }) async {
    final res = await _dio.post(ApiEndpoints.login, data: {
      'identifier': credential,
      'password':   password,
    });
    final payload = res.data['data'] as Map<String, dynamic>;
    await _saveTokens(payload);
    return payload;
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await SecureStorage.clearTokens(); // giữ remember-me credentials
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_store_id'); // xóa cache quán để không leak sang user khác
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get(ApiEndpoints.me);
    // /me trả về user trực tiếp (không wrap { data: ... })
    return res.data as Map<String, dynamic>;
  }

  Future<void> saveFcmToken(String token) async {
    await _dio.post(ApiEndpoints.fcmToken, data: {'fcmToken': token});
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await SecureStorage.saveAccessToken(data['accessToken']);
    await SecureStorage.saveRefreshToken(data['refreshToken']);
  }
}
