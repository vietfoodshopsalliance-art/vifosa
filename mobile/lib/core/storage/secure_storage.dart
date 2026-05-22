import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyAccessToken  = 'access_token';
  static const _keyRefreshToken = 'refresh_token';

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: _keyAccessToken, value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: _keyAccessToken);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _keyRefreshToken, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: _keyRefreshToken);

  static Future<void> clearAll() => _storage.deleteAll();

  // Chỉ xóa tokens — giữ nguyên remember-me credentials
  static Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  // Remember-me credentials
  static const _keySavedCredential = 'saved_credential';
  static const _keySavedPassword   = 'saved_password';

  static Future<void> saveRememberMe(String credential, String password) async {
    await _storage.write(key: _keySavedCredential, value: credential);
    await _storage.write(key: _keySavedPassword, value: password);
  }

  static Future<({String credential, String password})?> getRememberMe() async {
    final credential = await _storage.read(key: _keySavedCredential);
    final password   = await _storage.read(key: _keySavedPassword);
    if (credential == null || password == null) return null;
    return (credential: credential, password: password);
  }

  static Future<void> clearRememberMe() async {
    await _storage.delete(key: _keySavedCredential);
    await _storage.delete(key: _keySavedPassword);
  }
}
