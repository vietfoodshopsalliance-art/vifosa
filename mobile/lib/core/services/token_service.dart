// lib/core/services/token_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class TokenService {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<void> clearTokens();
}

// Override before use: tokenServiceProvider.overrideWithValue(TokenServiceImpl())
final tokenServiceProvider = Provider<TokenService>(
  (_) => throw UnimplementedError('tokenServiceProvider must be overridden'),
);
