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
  static const _sessionGateCompletedAtKey = 'session_gate_completed_at_iso';

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

  Future<bool> hasPersistedSession() async {
    final refreshToken = await readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      return true;
    }
    final accessToken = await readAccessToken();
    return accessToken != null && accessToken.isNotEmpty;
  }

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

  Future<void> markSessionGateComplete(DateTime? value) async {
    if (value == null) {
      await _storage.delete(key: _sessionGateCompletedAtKey);
    } else {
      await _storage.write(
        key: _sessionGateCompletedAtKey,
        value: value.toIso8601String(),
      );
    }
  }

  Future<bool> hasCompletedSessionGate() async {
    final v = await _storage.read(key: _sessionGateCompletedAtKey);
    return v != null && v.isNotEmpty;
  }

  Future<void> clearSessionGate() async {
    await _storage.delete(key: _sessionGateCompletedAtKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _lastBiometricAtKey);
    await _storage.delete(key: _sessionGateCompletedAtKey);
  }
}
