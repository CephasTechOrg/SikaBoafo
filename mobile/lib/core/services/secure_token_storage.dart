import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access and refresh tokens (`architecture.md` auth flow).
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  Future<void> writeAccessToken(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _accessKey);
    } else {
      await _storage.write(key: _accessKey, value: value);
    }
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<void> writeRefreshToken(String? value) async {
    if (value == null || value.isEmpty) {
      await _storage.delete(key: _refreshKey);
    } else {
      await _storage.write(key: _refreshKey, value: value);
    }
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
