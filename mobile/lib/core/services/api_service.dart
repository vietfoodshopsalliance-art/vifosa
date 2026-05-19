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
      : _baseUrl = apiBaseUrl,
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
      final token = await tokenService.getValidAccessToken();
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

    throw ApiException(
      statusCode: response.statusCode,
      message: (body['message'] as String?) ?? 'Lỗi không xác định.',
      code: body['code'] as String?,
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

  /// GET /users/me
  Future<Map<String, dynamic>> getMe() => get('/users/me');

  /// PATCH /users/me
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> body) =>
      patch('/users/me', body);

  /// PATCH /users/me/password
  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> body) =>
      patch('/users/me/password', body);

  /// GET /users/:id (public profile)
  Future<Map<String, dynamic>> getUserProfile(String userId) =>
      get('/users/$userId');

  // ── Địa chỉ ───────────────────────────────────────────────────────────────

  /// GET /addresses
  Future<Map<String, dynamic>> getAddresses() => get('/addresses');

  /// POST /addresses
  Future<Map<String, dynamic>> createAddress(Map<String, dynamic> body) =>
      post('/addresses', body);

  /// PATCH /addresses/:id
  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> body,
  ) =>
      patch('/addresses/$id', body);

  /// DELETE /addresses/:id
  Future<Map<String, dynamic>> deleteAddress(String id) =>
      delete('/addresses/$id');

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

  /// POST /stores/:storeId/menu/items
  Future<Map<String, dynamic>> createMenuItem(
    String storeId,
    Map<String, dynamic> body,
  ) =>
      post('/stores/$storeId/menu/items', body);

  /// PATCH /stores/:storeId/menu/items/:itemId
  Future<Map<String, dynamic>> updateMenuItem(
    String storeId,
    String itemId,
    Map<String, dynamic> body,
  ) =>
      patch('/stores/$storeId/menu/items/$itemId', body);

  /// DELETE /stores/:storeId/menu/items/:itemId
  Future<Map<String, dynamic>> deleteMenuItem(
    String storeId,
    String itemId,
  ) =>
      delete('/stores/$storeId/menu/items/$itemId');

  // ── Order endpoints ───────────────────────────────────────────────────────

  /// POST /orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) =>
      post('/orders', body);

  /// GET /orders/:id
  Future<Map<String, dynamic>> getOrder(String orderId) =>
      get('/orders/$orderId');

  /// GET /orders  — query: status, page, limit
  Future<Map<String, dynamic>> getMyOrders([Map<String, dynamic>? query]) =>
      get('/orders', queryParams: query);

  /// GET /orders/track/:code?t=:token  — guest tracking (no auth)
  Future<Map<String, dynamic>> trackOrder(String code, String token) =>
      get('/orders/track/$code', queryParams: {'t': token}, auth: false);

  /// PATCH /orders/:id/status
  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    Map<String, dynamic> body,
  ) =>
      patch('/orders/$orderId/status', body);

  /// POST /orders/:id/reported-paid  — khách báo đã chuyển khoản
  Future<Map<String, dynamic>> reportPaid(String orderId) =>
      post('/orders/$orderId/reported-paid', {});

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

  /// PATCH /stores/:storeId/orders/:orderId/accept
  Future<Map<String, dynamic>> acceptOrder(String storeId, String orderId) =>
      patch('/stores/$storeId/orders/$orderId/accept', {});

  /// PATCH /stores/:storeId/orders/:orderId/reject
  Future<Map<String, dynamic>> rejectOrder(
    String storeId,
    String orderId,
    Map<String, dynamic> body,
  ) =>
      patch('/stores/$storeId/orders/$orderId/reject', body);

  /// PATCH /stores/:storeId/orders/:orderId/confirm-payment
  Future<Map<String, dynamic>> confirmPayment(
    String storeId,
    String orderId,
  ) =>
      patch('/stores/$storeId/orders/$orderId/confirm-payment', {});

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

  /// DELETE /likes  — body: {targetType, targetId}
  Future<Map<String, dynamic>> unlike(Map<String, dynamic> body) =>
      post('/likes/remove', body); // DELETE với body dùng POST wrapper

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

  /// GET /notifications?page=&limit=
  Future<Map<String, dynamic>> getNotifications([
    Map<String, dynamic>? query,
  ]) =>
      get('/notifications', queryParams: query);

  /// PATCH /notifications/:id/read
  Future<Map<String, dynamic>> markNotificationRead(String id) =>
      patch('/notifications/$id/read', {});

  /// PATCH /notifications/read-all
  Future<Map<String, dynamic>> markAllNotificationsRead() =>
      patch('/notifications/read-all', {});

  /// POST /users/me/fcm-token
  Future<Map<String, dynamic>> registerFcmToken(String token) =>
      post('/users/me/fcm-token', {'token': token});

  /// DELETE /users/me/fcm-token
  Future<Map<String, dynamic>> removeFcmToken(String token) =>
      post('/users/me/fcm-token/remove', {'token': token});

  // ── Reports ───────────────────────────────────────────────────────────────

  /// POST /reports
  Future<Map<String, dynamic>> createReport(Map<String, dynamic> body) =>
      post('/reports', body);

  // ── Support tickets ───────────────────────────────────────────────────────

  /// POST /support-tickets
  Future<Map<String, dynamic>> createSupportTicket(
    Map<String, dynamic> body,
  ) =>
      post('/support-tickets', body);

  /// GET /support-tickets  — xem ticket của mình
  Future<Map<String, dynamic>> getMySupportTickets([
    Map<String, dynamic>? query,
  ]) =>
      get('/support-tickets', queryParams: query);

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
