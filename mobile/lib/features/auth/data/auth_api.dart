import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.phoneNumber,
    required this.merchantId,
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
    required this.onboardingRequired,
    required this.pinSet,
    required this.role,
  });

  final String userId;
  final String phoneNumber;
  final String? merchantId;
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;
  final bool onboardingRequired;
  final bool pinSet;

  /// `merchant_owner`, `manager`, `cashier`, `stock_keeper`, …
  final String role;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: (json['user_id'] ?? '') as String,
      phoneNumber: (json['phone_number'] ?? '') as String,
      merchantId: json['merchant_id'] as String?,
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
      isNewUser: (json['is_new_user'] ?? false) as bool,
      onboardingRequired: (json['onboarding_required'] ?? false) as bool,
      pinSet: (json['pin_set'] ?? false) as bool,
      role: (json['role'] as String?)?.trim().isNotEmpty == true
          ? (json['role'] as String).trim()
          : 'merchant_owner',
    );
  }
}

class OnboardingResult {
  const OnboardingResult({
    required this.merchantId,
    required this.storeId,
  });

  final String merchantId;
  final String storeId;

  factory OnboardingResult.fromJson(Map<String, dynamic> json) {
    return OnboardingResult(
      merchantId: (json['merchant_id'] ?? '') as String,
      storeId: (json['store_id'] ?? '') as String,
    );
  }
}

class AuthApi {
  AuthApi(this._apiClient);

  final ApiClient _apiClient;

  Future<int> requestOtp(String phoneNumber) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/auth/otp/request',
      data: {'phone_number': phoneNumber},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return (data['expires_in_minutes'] as int?) ?? 5;
    }
    return 5;
  }

  Future<AuthSession> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/auth/otp/verify',
      data: {'phone_number': phoneNumber, 'code': code},
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected auth response payload.');
    }
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> loginWithPin({
    required String phoneNumber,
    required String pin,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/auth/pin/login',
      data: {'phone_number': phoneNumber, 'pin': pin},
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected auth response payload.');
    }
    return AuthSession.fromJson(body);
  }

  Future<void> setPin(String pin) async {
    await _apiClient.dio.post<dynamic>(
      '/auth/pin/set',
      data: {'pin': pin},
    );
  }

  Future<OnboardingResult> completeOnboarding({
    required String businessName,
    String? businessType,
    String? storeName,
  }) async {
    final response = await _apiClient.dio.post<dynamic>(
      '/auth/onboarding/complete',
      data: {
        'business_name': businessName,
        'business_type': businessType,
        'store_name': storeName,
      },
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected onboarding response payload.');
    }
    return OnboardingResult.fromJson(body);
  }

  Future<void> logout() async {
    await _apiClient.dio.post<dynamic>('/auth/logout');
  }

  Future<void> deleteAccount() async {
    await _apiClient.dio.delete<dynamic>('/auth/account');
  }
}

String humanizeDioError(Object error) {
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      final d = (detail['detail'] as String).trim();
      if (d == 'pin_not_set') {
        return 'No PIN set for this number. Use Create account or tap Forgot PIN.';
      }
      if (d == 'invalid_credentials' || d == 'Invalid credentials') {
        return 'Incorrect phone number or PIN. Please try again.';
      }
      // Filter out developer-facing error strings before showing to user.
      final looksDev = d.isEmpty ||
          d.contains('Traceback') ||
          d.contains('Exception') ||
          d.contains('Error:') ||
          d.contains('psycopg') ||
          d.contains('sqlalchemy');
      if (!looksDev) return d;
    }
    final status = error.response?.statusCode;
    if (_isOfflineish(error)) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (status == 401) return 'Incorrect phone number or PIN.';
    if (status == 403) return 'Access denied. Please contact support.';
    if (status == 404) return 'Account not found. Check your phone number.';
    if (status == 429) return 'Too many attempts. Please wait a moment.';
    if (status != null && status >= 500) {
      return 'Server is having trouble right now. Please try again shortly.';
    }
    return 'Something went wrong. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}

bool _isOfflineish(DioException e) {
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;
}
