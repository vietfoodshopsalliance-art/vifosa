// lib/core/network/dio_client.dart

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env.dart';
import 'api_endpoints.dart';

const _kAccessToken  = 'access_token';
const _kRefreshToken = 'refresh_token';

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

class DioClient {
  late final Dio dio;
  late final _AuthInterceptor _authInterceptor;
  final _storage = const FlutterSecureStorage();

  /// Gọi từ auth_provider sau khi khởi tạo để wire callback logout.
  set forceLogout(void Function() cb) => _authInterceptor.onForceLogout = cb;

  DioClient() {
    dio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(LogInterceptor(
      requestHeader:  true,
      responseHeader: false,
      requestBody:    true,
      responseBody:   true,
      error:          true,
      logPrint: (o) => print('[DIO] $o'),
    ));

    _authInterceptor = _AuthInterceptor(dio, _storage);
    dio.interceptors.add(_authInterceptor);
  }

  // ── Token helpers ──────────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: accessToken),
      _storage.write(key: _kRefreshToken, value: refreshToken),
    ]);
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
    ]);
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);

  // ── Shortcut methods ───────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      dio.get<T>(path, queryParameters: queryParameters, options: options);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      dio.post<T>(path, data: data, options: options);

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      dio.put<T>(path, data: data, options: options);

        Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      dio.patch<T>(path, data: data, options: options);

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) =>
      dio.delete<T>(path, data: data, options: options);
}

// ─── Auth interceptor ─────────────────────────────────────────────────────────

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  void Function()? onForceLogout;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: _kAccessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    print('[DIO ERROR] ${err.type} | status: ${err.response?.statusCode}');
    print('[DIO ERROR] message: ${err.message}');
    print('[DIO ERROR] url: ${err.requestOptions.uri}');
    print('[DIO ERROR] response: ${err.response?.data}');

    final isRefreshCall = err.requestOptions.path.contains(ApiEndpoints.refresh);
    if (err.response?.statusCode == 401 && !_isRefreshing && !isRefreshCall) {
      _isRefreshing = true;
      try {
        final newToken = await _refreshAccessToken();
        if (newToken != null) {
          final opts = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        await _storage.delete(key: _kAccessToken);
        await _storage.delete(key: _kRefreshToken);
        onForceLogout?.call();
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }

  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return null;

    final res = await _dio.post(
      ApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
      options: Options(headers: {}),
    );

    final resBody = res.data is Map && res.data['data'] is Map
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    final newAccess  = resBody['accessToken']  as String?;
    final newRefresh = resBody['refreshToken'] as String?;
    if (newAccess != null) {
      await _storage.write(key: _kAccessToken, value: newAccess);
    }
    if (newRefresh != null) {
      await _storage.write(key: _kRefreshToken, value: newRefresh);
    }
    return newAccess;
  }
}

// lib/core/network/dio_client.dart