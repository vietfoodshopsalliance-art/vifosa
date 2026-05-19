import 'package:dio/dio.dart';
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
      'username': username,
      'nickname': nickname,
      'email':    email,
      'phone':    phone,
      'password': password,
    });
    await _saveTokens(res.data);
    return res.data;
  }

  Future<Map<String, dynamic>> login({
    required String credential,
    required String password,
  }) async {
    final res = await _dio.post(ApiEndpoints.login, data: {
      'credential': credential,
      'password':   password,
    });
    await _saveTokens(res.data);
    return res.data;
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await SecureStorage.clearAll();
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get(ApiEndpoints.me);
    return res.data;
  }

  Future<void> saveFcmToken(String token) async {
    await _dio.post(ApiEndpoints.fcmToken, data: {'token': token});
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await SecureStorage.saveAccessToken(data['accessToken']);
    await SecureStorage.saveRefreshToken(data['refreshToken']);
  }
}
