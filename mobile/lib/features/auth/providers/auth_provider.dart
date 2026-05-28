import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/storage/secure_storage.dart';

// ─── State ──────────────────────────────────────────────────────

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.initial || status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );
}

// ─── Notifier ───────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);
    final token = await SecureStorage.getAccessToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repo.getMe();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String credential,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final data = await _repo.login(
        credential: credential,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: data['user'],
      );
    } on DioException catch (e) { // ← fix lỗi 1: Dio 5.x dùng DioException
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseDioError(e),
      );
    } on Exception catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Đã có lỗi xảy ra',
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
      final data = await _repo.register(
        username: username,
        nickname: nickname,
        email: email,
        phone: phone,
        password: password,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: data['user'],
      );
    } on DioException catch (e) { // ← fix lỗi 1
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseDioError(e),
      );
    } on Exception catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: 'Đã có lỗi xảy ra',
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _repo.getMe();
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  Future<void> saveFcmToken(String token) async {
    try {
      await _repo.saveFcmToken(token);
    } catch (_) {}
  }

  // Parse lỗi từ backend Fastify: { message } hoặc { issues: [{ message }] }
  String _parseDioError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data['message'] != null) return data['message'] as String;
        final issues = data['issues'];
        if (issues is List && issues.isNotEmpty) {
          final msg = issues.first['message'];
          if (msg is String) return msg;
        }
        return 'Lỗi xác thực dữ liệu';
      }
    } catch (_) {}
    return switch (e.type) {
      DioExceptionType.connectionTimeout => 'Hết thời gian kết nối',
      DioExceptionType.receiveTimeout    => 'Server phản hồi quá chậm',
      DioExceptionType.connectionError   => 'Không thể kết nối đến server',
      _                                  => 'Lỗi kết nối',
    };
  }
}

// ─── Providers ──────────────────────────────────────────────────

final authRepositoryProvider = Provider((_) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);