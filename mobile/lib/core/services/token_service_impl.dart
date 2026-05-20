// lib/core/services/token_service_impl.dart

import '../storage/secure_storage.dart';
import 'token_service.dart';

class TokenServiceImpl implements TokenService {
  @override
  Future<String?> getAccessToken() => SecureStorage.getAccessToken();

  @override
  Future<String?> getRefreshToken() => SecureStorage.getRefreshToken();

  @override
  Future<void> saveAccessToken(String token) =>
      SecureStorage.saveAccessToken(token);

  @override
  Future<void> saveRefreshToken(String token) =>
      SecureStorage.saveRefreshToken(token);

  @override
  Future<void> clearTokens() => SecureStorage.clearAll();
}
