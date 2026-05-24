import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _create();
    return _instance!;
  }

  static Dio _create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: Env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );

    dio.interceptors.add(_AuthInterceptor(dio));
    return dio;
  }
}

// ─── Interceptor ────────────────────────────────────────────────

class _AuthInterceptor extends QueuedInterceptorsWrapper {
  _AuthInterceptor(this._dio);

  final Dio _dio;

  // Dio riêng biệt cho refresh — tránh vòng lặp interceptor
  late final _refreshDio = Dio(
    BaseOptions(baseUrl: Env.apiBaseUrl),
  );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err, // ← Dio 5.x dùng DioException, không phải DioError
    ErrorInterceptorHandler handler,
  ) async {
    // Chỉ xử lý 401, không retry chính endpoint refresh
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/refresh')) {
      try {
        final newToken = await _tryRefresh();
        if (newToken != null) {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        }
      } catch (_) {
        // Refresh thất bại
      }
      await SecureStorage.clearAll();
    }
    handler.next(err);
  }

  Future<String?> _tryRefresh() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null) return null;

    final response = await _refreshDio.post(
      ApiEndpoints.refresh,
      data: {'refreshToken': refreshToken},
    );

    // Spec v3.1: response bọc trong { success, data: { accessToken, refreshToken } }
    final body = response.data as Map<String, dynamic>;
    final data = (body['data'] ?? body) as Map<String, dynamic>;
    final newAccess  = data['accessToken']  as String;
    final newRefresh = data['refreshToken'] as String;

    await SecureStorage.saveAccessToken(newAccess);
    await SecureStorage.saveRefreshToken(newRefresh);

    return newAccess;
  }
}

// ── Riverpod wrapper ─────────────────────────────────────────────────────────

class DioClientRef {
  final Dio dio = DioClient.instance;
}

final dioClientProvider = Provider<DioClientRef>((_) => DioClientRef());