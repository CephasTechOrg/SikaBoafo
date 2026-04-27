import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access and refresh tokens (`architecture.md` auth flow).
class SecureTokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _lastBiometricAtKey = 'last_biometric_at_iso';

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

  Future<void> setBiometricEnabled(bool enabled) {
    return _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _biometricEnabledKey);
    return v == '1' || v == 'true';
  }

  Future<void> writeLastBiometricAt(DateTime? value) async {
    if (value == null) {
      await _storage.delete(key: _lastBiometricAtKey);
    } else {
      await _storage.write(key: _lastBiometricAtKey, value: value.toIso8601String());
    }
  }

  Future<DateTime?> readLastBiometricAt() async {
    final v = await _storage.read(key: _lastBiometricAtKey);
    if (v == null || v.isEmpty) return null;
    return DateTime.tryParse(v);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _lastBiometricAtKey);
  }
}
