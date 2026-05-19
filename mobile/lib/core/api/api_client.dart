// lib/core/api/api_client.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

// ---------------------------------------------------------------------------
// ApiClient — thin adapter trên ApiService
//
// menu_provider.dart và store_detail_provider.dart dùng interface:
//   _api.get(path)
//   _api.post(path, body: {...})
//   _api.patch(path, body: {...})
//   _api.delete(path)
//
// ApiService dùng positional args: get(path, queryParams: ...).
// ApiClient bridge hai signature này.
// ---------------------------------------------------------------------------

class ApiClient {
  final ApiService _service;

  ApiClient(this._service);

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) =>
      _service.get(path, queryParams: queryParams);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) =>
      _service.post(path, body);

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic> body = const {},
  }) =>
      _service.patch(path, body);

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic> body = const {},
  }) =>
      _service.put(path, body);

  Future<Map<String, dynamic>> delete(String path) =>
      _service.delete(path);
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final apiClientProvider = Provider<ApiClient>((ref) {
  final service = ref.watch(apiServiceProvider);
  return ApiClient(service);
});

// lib/core/api/api_client.dart