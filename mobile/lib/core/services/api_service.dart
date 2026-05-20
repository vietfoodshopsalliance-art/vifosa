// lib/core/services/api_service.dart
// HTTP client trung tâm — bọc toàn bộ REST calls tới backend Vifosa

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vifosa/core/config/env.dart';
import 'package:vifosa/core/services/token_service.dart';

// --------
// Exceptions
// --------

class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
  });

  final int statusCode;
  final String message;
  final String? code; // error code từ backend (vd: "ORDER_NOT_FOUND")

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

// ---------------------------------------------------------------------------
// Response wrapper
// ---------------------------------------------------------------------------

class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    this.meta,
  });

  final T data;
  final Map<String, dynamic>? meta; // pagination, total, v.v.
}

// ---------------------------------------------------------------------------
// ApiService
// ---------------------------------------------------------------------------

class ApiService {
  ApiService({required this.tokenService})
      : _baseUrl = Env.apiBaseUrl,
        _client = http.Client();

  final String _baseUrl;
  final http.Client _client;
  final TokenService tokenService;

  // ── Helpers ──────────────────────────────────────────────────────────────

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    final cleaned = query.map(
      (k, v) => MapEntry(k, v?.toString()),
    )..removeWhere((_, v) => v == null);
    return uri.replace(queryParameters: cleaned.cast<String, String>());
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (auth) {
      final token = await tokenService.getAccessToken();
      if (token != null) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Decode + throw on non-2xx
  Map<String, dynamic> _decode(http.Response response) {
    late Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Phản hồi không hợp lệ từ máy chủ.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Spec v3.1: lỗi được bọc trong body['error']['code'] và body['error']['message']
    final errorObj = body['error'] as Map<String, dynamic>?;
    throw ApiException(
      statusCode: response.statusCode,
      message: (errorObj?['message'] as String?) ??
          (body['message'] as String?) ??
          'Lỗi không xác định.',
      code: (errorObj?['code'] as String?) ?? (body['code'] as String?),
    );
  }

  Future<Map<String, dynamic>> _safeCall(
    Future<http.Response> Function() call,
  ) async {
    try {
      final response = await call();
      return _decode(response);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw NetworkException('Không có kết nối mạng: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Lỗi kết nối: ${e.message}');
    }
  }

  // ── CRUD primitives ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
    bool auth = true,
  }) async {
    return _safeCall(
      () async => _client.get(_uri(path, queryParams), headers: await _headers(auth: auth)),
    );
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _safeCall(
      () async => _client.post(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _safeCall(
      () async => _client.patch(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _safeCall(
      () async => _client.put(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) async {
    return _safeCall(
      () async =>
          _client.delete(_uri(path), headers: await _headers(auth: auth)),
    );
  }

  // DELETE với body (dùng cho /me/fcm-token theo spec v3.1)
  Future<Map<String, dynamic>> deleteWithBody(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    return _safeCall(() async {
      final request = http.Request('DELETE', _uri(path));
      final headers = await _headers(auth: auth);
      request.headers.addAll(headers);
      request.body = jsonEncode(body);
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
  }

  // Multipart upload (ảnh Cloudinary qua backend nếu cần proxy)
  Future<Map<String, dynamic>> upload(
    String path,
    File file, {
    String fieldName = 'file',
    Map<String, String>? fields,
    bool auth = true,
  }) async {
    final headers = await _headers(auth: auth);
    headers.remove(HttpHeaders.contentTypeHeader); // multipart tự set

    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    if (fields != null) request.fields.addAll(fields);

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on SocketException catch (e) {
      throw NetworkException('Không có kết nối mạng: ${e.message}');
    }
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────

  /// POST /auth/register
  Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      post('/auth/register', body, auth: false);

  /// POST /auth/login
  Future<Map<String, dynamic>> login(Map<String, dynamic> body) =>
      post('/auth/login', body, auth: false);

  /// POST /auth/refresh  — gọi với refreshToken trong body
  Future<Map<String, dynamic>> refreshToken(String refreshToken) =>
      post('/auth/refresh', {'refreshToken': refreshToken}, auth: false);

  /// POST /auth/logout
  Future<Map<String, dynamic>> logout(String refreshToken) =>
      post('/auth/logout', {'refreshToken': refreshToken});

  // ── User endpoints ────────────────────────────────────────────────────────

  /// GET /me
  Future<Map<String, dynamic>> getMe() => get('/me');

  /// PUT /me
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) =>
      put('/me', body);

  /// POST /auth/change-password
  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> body) =>
      post('/auth/change-password', body);

  /// GET /users/:username (public profile)
  Future<Map<String, dynamic>> getUserProfile(String username) =>
      get('/users/$username', auth: false);

  // ── Địa chỉ ───────────────────────────────────────────────────────────────

  /// GET /me/addresses
  Future<Map<String, dynamic>> getAddresses() => get('/me/addresses');

  /// POST /me/addresses
  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> body) =>
      post('/me/addresses', body);

  /// PUT /me/addresses/:id
  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> body,
  ) =>
      put('/me/addresses/$id', body);

  /// DELETE /me/addresses/:id
  Future<Map<String, dynamic>> deleteAddress(String id) =>
      delete('/me/addresses/$id');

  // ── Store endpoints ───────────────────────────────────────────────────────

  /// GET /stores  — feed khám phá; query: lat, lng, radius, page, limit
  Future<Map<String, dynamic>> getStores(Map<String, dynamic> query) =>
      get('/stores', queryParams: query);

  /// GET /stores/:id
  Future<Map<String, dynamic>> getStore(String storeId) =>
      get('/stores/$storeId');

  /// POST /stores
  Future<Map<String, dynamic>> createStore(Map<String, dynamic> body) =>
      post('/stores', body);

  /// PATCH /stores/:id
  Future<Map<String, dynamic>> updateStore(
    String storeId,
    Map<String, dynamic> body,
  ) =>
      patch('/stores/$storeId', body);

  // ── Menu endpoints ────────────────────────────────────────────────────────

  /// GET /stores/:storeId/menu
  Future<Map<String, dynamic>> getMenu(String storeId) =>
      get('/stores/$storeId/menu');

  /// POST /stores/:storeId/items
  Future<Map<String, dynamic>> createMenuItem(
    String storeId,
    Map<String, dynamic> body,
  ) =>
      post('/stores/$storeId/items', body);

  /// PATCH /stores/:storeId/items/:itemId
  Future<Map<String, dynamic>> updateMenuItem(
    String storeId,
    String itemId,
    Map<String, dynamic> body,
  ) =>
      patch('/stores/$storeId/items/$itemId', body);

  /// DELETE /stores/:storeId/items/:itemId
  Future<Map<String, dynamic>> deleteMenuItem(
    String storeId,
    String itemId,
  ) =>
      delete('/stores/$storeId/items/$itemId');

  // ── Order endpoints ───────────────────────────────────────────────────────

  /// POST /orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) =>
      post('/orders', body);

  /// GET /orders/:id
  Future<Map<String, dynamic>> getOrder(String orderId) =>
      get('/orders/$orderId');

  /// GET /me/orders  — query: status, cursor, limit
  Future<Map<String, dynamic>> getMyOrders([Map<String, dynamic>? query]) =>
      get('/me/orders', queryParams: query);

  /// GET /orders/track?code=:code&phone=:phone  — guest tracking (no auth)
  Future<Map<String, dynamic>> trackOrder(String code, String phone) =>
      get('/orders/track', queryParams: {'code': code, 'phone': phone}, auth: false);

  /// POST /orders/:id/report-paid  — khách báo đã chuyển khoản
  Future<Map<String, dynamic>> reportPaid(String orderId) =>
      post('/orders/$orderId/report-paid', {});

  /// POST /orders/:id/cancel
  Future<Map<String, dynamic>> cancelOrder(
    String orderId,
    Map<String, dynamic> body,
  ) =>
      post('/orders/$orderId/cancel', body);

  // ── Store order management (quán) ────────────────────────────────────────

  /// GET /stores/:storeId/orders  — query: status, page, limit
  Future<Map<String, dynamic>> getStoreOrders(
    String storeId, [
    Map<String, dynamic>? query,
  ]) =>
      get('/stores/$storeId/orders', queryParams: query);

  /// POST /orders/:orderId/accept
  Future<Map<String, dynamic>> acceptOrder(String orderId) =>
      post('/orders/$orderId/accept', {});

  /// POST /orders/:orderId/reject
  Future<Map<String, dynamic>> rejectOrder(
    String orderId,
    Map<String, dynamic> body,
  ) =>
      post('/orders/$orderId/reject', body);

  /// POST /orders/:orderId/confirm-money-received
  Future<Map<String, dynamic>> confirmPayment(
    String orderId,
    Map<String, dynamic> body,
  ) =>
      post('/orders/$orderId/confirm-money-received', body);

  // ── Reviews ───────────────────────────────────────────────────────────────

  /// GET /reviews?toEntityId=&toEntityType=&page=&limit=
  Future<Map<String, dynamic>> getReviews(Map<String, dynamic> query) =>
      get('/reviews', queryParams: query);

  /// POST /reviews
  Future<Map<String, dynamic>> createReview(Map<String, dynamic> body) =>
      post('/reviews', body);

  /// PATCH /reviews/:id
  Future<Map<String, dynamic>> updateReview(
    String reviewId,
    Map<String, dynamic> body,
  ) =>
      patch('/reviews/$reviewId', body);

  /// POST /reviews/:id/reply  — quán phản hồi đánh giá
  Future<Map<String, dynamic>> replyReview(
    String reviewId,
    Map<String, dynamic> body,
  ) =>
      post('/reviews/$reviewId/reply', body);

  // ── Social ────────────────────────────────────────────────────────────────

  /// GET /posts?page=&limit=
  Future<Map<String, dynamic>> getPosts([Map<String, dynamic>? query]) =>
      get('/posts', queryParams: query);

  /// GET /posts/:id
  Future<Map<String, dynamic>> getPost(String postId) =>
      get('/posts/$postId');

  /// POST /posts
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> body) =>
      post('/posts', body);

  /// DELETE /posts/:id
  Future<Map<String, dynamic>> deletePost(String postId) =>
      delete('/posts/$postId');

  /// POST /likes
  Future<Map<String, dynamic>> like(Map<String, dynamic> body) =>
      post('/likes', body);

  /// POST /likes  — toggle unlike (same endpoint, liked: false khi unlike)
  Future<Map<String, dynamic>> unlike(Map<String, dynamic> body) =>
      post('/likes', body);

  /// GET /posts/:postId/comments
  Future<Map<String, dynamic>> getComments(
    String postId, [
    Map<String, dynamic>? query,
  ]) =>
      get('/posts/$postId/comments', queryParams: query);

  /// POST /posts/:postId/comments
  Future<Map<String, dynamic>> createComment(
    String postId,
    Map<String, dynamic> body,
  ) =>
      post('/posts/$postId/comments', body);

  /// DELETE /posts/:postId/comments/:commentId
  Future<Map<String, dynamic>> deleteComment(
    String postId,
    String commentId,
  ) =>
      delete('/posts/$postId/comments/$commentId');

  // ── Notifications ─────────────────────────────────────────────────────────

  /// GET /me/notifications?cursor=&limit=
  Future<Map<String, dynamic>> getNotifications([
    Map<String, dynamic>? query,
  ]) =>
      get('/me/notifications', queryParams: query);

  /// PATCH /me/notifications/:id/read
  Future<Map<String, dynamic>> markNotificationRead(String id) =>
      patch('/me/notifications/$id/read', {});

  /// PATCH /me/notifications/read-all
  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      patch('/me/notifications/read-all', {});

  /// POST /me/fcm-token
  Future<Map<String, dynamic>> registerFcmToken(String token) =>
      post('/me/fcm-token', {'fcmToken': token});

  /// DELETE /me/fcm-token
  Future<Map<String, dynamic>> removeFcmToken(String token) =>
      deleteWithBody('/me/fcm-token', {'fcmToken': token});

  // ── Reports ───────────────────────────────────────────────────────────────

  /// POST /reports
  Future<Map<String, dynamic>> createReport(Map<String, dynamic> body) =>
      post('/reports', body);

  // ── Support tickets ───────────────────────────────────────────────────────

  /// POST /support/tickets
  Future<Map<String, dynamic>> createSupportTicket(
    Map<String, dynamic> body,
  ) =>
      post('/support/tickets', body, auth: false);

  /// GET /me/support/tickets
  Future<Map<String, dynamic>> getMySupportTickets([
    Map<String, dynamic>? query,
  ]) =>
      get('/me/support/tickets', queryParams: query);

  // ── Settings (public read) ────────────────────────────────────────────────

  /// GET /settings/:key
  Future<Map<String, dynamic>> getSetting(String key) =>
      get('/settings/$key', auth: false);

  void dispose() => _client.close();
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final apiServiceProvider = Provider<ApiService>((ref) {
  final tokenService = ref.watch(tokenServiceProvider);
  final service = ApiService(tokenService: tokenService);
  ref.onDispose(service.dispose);
  return service;
});
