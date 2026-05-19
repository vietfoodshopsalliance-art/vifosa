// mobile/lib/features/auth/providers/auth_provider.dart

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/models/user.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/socket_client.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String activeRole;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.activeRole = 'customer',
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? activeRole,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        activeRole: activeRole ?? this.activeRole,
        error: error,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(dioClientProvider);
  final notifier = AuthNotifier(client);
  client.forceLogout = notifier.logout;
  return notifier;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final DioClient _client;

  AuthNotifier(this._client)
      : super(const AuthState(status: AuthStatus.loading)) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    try {
      await _doRestore().timeout(const Duration(seconds: 4));
    } on TimeoutException {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _doRestore() async {
    String? token;
    try {
      token = await _client.accessToken;
    } catch (_) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    if (token == null) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final res = await _client.dio.get(ApiEndpoints.me);
      // Backend trả { success, data: { user } } hoặc { user } — unwrap an toàn
      final body = _unwrap(res.data as Map<String, dynamic>);
      final user = AppUser.fromJson(body);
      if (mounted) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          activeRole: user.roles.first,
        );
      }
      unawaited(_registerFcmToken());
      unawaited(SocketClient().connect(accessToken: token));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await _client.clearTokens();
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final res = await _client.dio.post(ApiEndpoints.login, data: {
        'identifier': identifier,
        'password': password,
      });
      // Unwrap { success: true, data: { accessToken, refreshToken, user } }
      final body = _unwrap(res.data as Map<String, dynamic>);
      await _client.saveTokens(
        accessToken:  body['accessToken']  as String,
        refreshToken: body['refreshToken'] as String,
      );
      final user = AppUser.fromJson(body['user'] as Map<String, dynamic>);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        activeRole: user.roles.first,
      );
      unawaited(_registerFcmToken());
      unawaited(SocketClient().connect(accessToken: body['accessToken'] as String));
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  Future<void> register({
    required String username,
    required String nickname,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
        await _client.dio.post(ApiEndpoints.register, data: {
          'username': username,
          'nickname': nickname,
          'email': email,
          'phone': phone,
          'password': password,
          'tosAccepted': true,
        });
      await login(identifier: username, password: password);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
    }
  }

  Future<void> logout() async {
    try { await _client.dio.post(ApiEndpoints.logout, data: {}); } catch (_) {}
    SocketClient().disconnect();
    await _client.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void switchRole(String role) {
    if (state.user?.roles.contains(role) ?? false) {
      state = state.copyWith(activeRole: role);
    }
  }

/// Gọi lại /me để cập nhật user + roles sau khi backend thay đổi
  /// (ví dụ: vừa tạo quán → backend đã cấp role store_owner)
  Future<void> refreshAuth() async {
    if (!state.isAuthenticated) return;
    try {
      final res = await _client.dio.get(ApiEndpoints.me);
      final body = _unwrap(res.data as Map<String, dynamic>);
      final user = AppUser.fromJson(body);
      if (mounted) {
        state = state.copyWith(
          user: user,
          activeRole: user.roles.contains('store_owner') ? 'store_owner' : state.activeRole,
        );
      }
    } catch (_) {
      // Không throw — đây là best-effort refresh
    }
  }

  Future<void> updateFcmToken(String token) async {
    if (!state.isAuthenticated) return;
    try {
      await _client.dio.post(ApiEndpoints.fcmToken, data: {'fcmToken': token});
    } catch (_) {}
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await updateFcmToken(token);
    } catch (_) {}
  }

  /// Backend có thể trả { success, data: {...} } hoặc trực tiếp {...}
  /// Hàm này unwrap lớp data nếu có.
  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    if (raw.containsKey('data') && raw['data'] is Map<String, dynamic>) {
      return raw['data'] as Map<String, dynamic>;
    }
    return raw;
  }

  String _extractError(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        // Thử unwrap lớp data trước
        final inner = data['data'] ?? data;
        return (inner['message'] ?? data['message'] ?? e.toString()) as String;
      }
    } catch (_) {}
    return e.toString();
  }
}

