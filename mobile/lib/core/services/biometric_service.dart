import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum BiometricAvailability {
  available,
  notEnrolled,
  notSupported,
  unknown,
}

class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricAvailability> availability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricAvailability.notSupported;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return BiometricAvailability.notEnrolled;

      final types = await _auth.getAvailableBiometrics();
      return types.isEmpty
          ? BiometricAvailability.notEnrolled
          : BiometricAvailability.available;
    } catch (_) {
      return BiometricAvailability.unknown;
    }
  }

  Future<bool> authenticate({
    required String reason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e, st) {
      if (kDebugMode) {
        debugPrint('Biometric auth PlatformException: ${e.code} ${e.message}');
        debugPrintStack(stackTrace: st);
      }
      return false;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Biometric auth error: $e');
        debugPrintStack(stackTrace: st);
      }
      return false;
    }
  }
}

