import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/env/app_config.dart';
import 'secure_token_storage.dart';

/// JSON API client with auth header injection.
class ApiClient {
  ApiClient({
    required SecureTokenStorage tokenStorage,
    Dio? dio,
  }) : _tokenStorage = tokenStorage {
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
        onError: (e, handler) {
          if (kDebugMode) {
            debugPrint('API ${e.requestOptions.method} ${e.requestOptions.path}: ${e.message}');
          }
          handler.next(e);
        },
      ),
    );
  }

  final SecureTokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;
}
