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
    String tosVersion = '1.0',
  }) async {
    final res = await _dio.post(ApiEndpoints.register, data: {
      'username': username,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'password': password,
      'tosAccepted': true,
      'tosVersion': tosVersion,
    });
    return (res.data as Map<String,dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final res = await _dio.post(ApiEndpoints.login, data: {
      'identifier': identifier,
      'password': password,
    });
    final data = res.data as Map<String, dynamic>;
    await SecureStorage.saveAccessToken(data['data']['accessToken'] as String);
    await SecureStorage.saveRefreshToken(data['data']['refreshToken'] as String);
    return data;
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final oldRefresh = await SecureStorage.getRefreshToken();
    if (oldRefresh == null) throw Exception('Không có refresh token');
    final res = await _dio.post(ApiEndpoints.refresh, data: {
      'refreshToken': oldRefresh,
    });
    final data = res.data as Map<String, dynamic>;
    await SecureStorage.saveAccessToken(data['data']['accessToken'] as String);
    await SecureStorage.saveRefreshToken(data['data']['refreshToken'] as String);
    return data;
  }

  Future<void> logout() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    try {
      await _dio.post(ApiEndpoints.logout, data: {'refreshToken': refreshToken});
    } catch (_) {
    } finally {
      await SecureStorage.clearAll();
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get(ApiEndpoints.me);
    return (res.data as Map<String,dynamic>)['data'] as Map<String, dynamic>;
  }

  Future<void> saveFcmToken(String token) async {
    await _dio.post(ApiEndpoints.fcmToken, data: {'fcmToken': token});
  }

  Future<void> acceptTos(String tosVersion) async {
    await _dio.post(ApiEndpoints.tosAccept, data: {'version': tosVersion});
  }
}
