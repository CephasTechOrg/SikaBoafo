import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/env/app_config.dart';
import 'secure_token_storage.dart';

/// JSON API client with auth header injection.
class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    Future<void> Function()? onUnauthorized,
    Dio? dio,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: '${AppConfig.apiBaseUrl}${AppConfig.apiV1Prefix}',
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final statusCode = e.response?.statusCode;
          final hadAuthHeader =
              e.requestOptions.headers['Authorization'] != null;
          final isAuthEndpoint = e.requestOptions.path.contains('/auth/');

          // If a previously authenticated request returns 401, clear session and redirect.
          if (statusCode == 401 && hadAuthHeader && !isAuthEndpoint) {
            if (!_isHandlingUnauthorized) {
              _isHandlingUnauthorized = true;
              try {
                await _tokenStorage.clearSession();
                await _onUnauthorized?.call();
              } finally {
                _isHandlingUnauthorized = false;
              }
            }
          }

          if (kDebugMode) {
            debugPrint(
                'API ${e.requestOptions.method} ${e.requestOptions.path}: ${e.message}');
          }
          handler.next(e);
        },
      ),
    );
  }

  final SecureTokenStorage _tokenStorage;
  final Future<void> Function()? _onUnauthorized;
  late final Dio _dio;
  bool _isHandlingUnauthorized = false;

  Dio get dio => _dio;
}
