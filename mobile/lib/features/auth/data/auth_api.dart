import 'package:dio/dio.dart';

import '../../../core/services/api_client.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.phoneNumber,
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
    required this.onboardingRequired,
  });

  final String userId;
  final String phoneNumber;
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;
  final bool onboardingRequired;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: (json['user_id'] ?? '') as String,
      phoneNumber: (json['phone_number'] ?? '') as String,
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
      isNewUser: (json['is_new_user'] ?? false) as bool,
      onboardingRequired: (json['onboarding_required'] ?? false) as bool,
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

  Future<void> completeOnboarding({
    required String businessName,
    String? businessType,
    String? storeName,
  }) async {
    await _apiClient.dio.post<dynamic>(
      '/auth/onboarding/complete',
      data: {
        'business_name': businessName,
        'business_type': businessType,
        'store_name': storeName,
      },
    );
  }
}

String humanizeDioError(Object error) {
  if (error is DioException) {
    final detail = error.response?.data;
    if (detail is Map<String, dynamic> && detail['detail'] is String) {
      return detail['detail'] as String;
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Cannot reach server. Check API_BASE_URL and network.';
    }
    return error.message ?? 'Request failed.';
  }
  return 'Unexpected error. Please try again.';
}
