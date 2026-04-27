import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/env/app_config.dart';
import 'secure_token_storage.dart';

/// JSON API client with auth header injection.
class ApiClient {
  static const _skipAuthHeaderExtra = 'skip_auth_header';
  static const _skipSessionRecoveryExtra = 'skip_session_recovery';
  static const _retriedAfterRefreshExtra = 'retried_after_refresh';
  static const _refreshPath = '/auth/refresh';

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
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 75),
            sendTimeout: const Duration(seconds: 30),
            headers: {'Accept': 'application/json'},
          ),
        );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuthHeader = options.extra[_skipAuthHeaderExtra] == true;
          if (!skipAuthHeader) {
            var token = await _tokenStorage.readAccessToken();
            // Proactively refresh if the token is expired or expiring within
            // the next 2 minutes, rather than waiting for a 401 response.
            if (token != null &&
                token.isNotEmpty &&
                isTokenExpiredOrExpiringSoon(token)) {
              final refreshed = await _refreshIfNeeded();
              if (refreshed) {
                token = await _tokenStorage.readAccessToken();
              }
            }
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          final statusCode = e.response?.statusCode;
          final hadAuthHeader =
              e.requestOptions.headers['Authorization'] != null;
          final isAuthEndpoint = e.requestOptions.path.contains('/auth/');
          final alreadyRetried =
              e.requestOptions.extra[_retriedAfterRefreshExtra] == true;
          final skipSessionRecovery =
              e.requestOptions.extra[_skipSessionRecoveryExtra] == true;

          // If a protected request returns 401, try one refresh before logging out.
          if (statusCode == 401 &&
              hadAuthHeader &&
              !isAuthEndpoint &&
              !skipSessionRecovery) {
            final refreshed = !alreadyRetried && await _refreshIfNeeded();
            if (refreshed) {
              final nextAccessToken = await _tokenStorage.readAccessToken();
              if (nextAccessToken != null && nextAccessToken.isNotEmpty) {
                try {
                  e.requestOptions.headers['Authorization'] =
                      'Bearer $nextAccessToken';
                  e.requestOptions.extra[_retriedAfterRefreshExtra] = true;
                  final retryResponse = await _dio.fetch<dynamic>(
                    e.requestOptions,
                  );
                  return handler.resolve(retryResponse);
                } on DioException {
                  // Fall through to the normal unauthorized path below.
                }
              }
            }

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
  Future<bool>? _refreshFuture;

  Dio get dio => _dio;

  Future<bool> _refreshIfNeeded() async {
    final existing = _refreshFuture;
    if (existing != null) {
      return existing;
    }

    final future = _refreshSession();
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    }
  }

  /// Public wrapper so callers (e.g. SyncStatusController) can trigger a
  /// proactive refresh without making a full network request.
  Future<bool> refreshIfNeeded() => _refreshIfNeeded();

  /// Returns true if [token] is expired or will expire within [bufferSeconds].
  /// Decodes the JWT payload via base64 — never throws, treats any parse
  /// failure as "treat as expired".
  static bool isTokenExpiredOrExpiringSoon(
    String token, {
    int bufferSeconds = 120,
  }) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final padded =
          parts[1].padRight(parts[1].length + (-parts[1].length % 4), '=');
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (payload is! Map<String, dynamic>) return true;
      final exp = payload['exp'];
      if (exp is! int) return true;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now()
          .toUtc()
          .isAfter(expiresAt.subtract(Duration(seconds: bufferSeconds)));
    } catch (_) {
      return true;
    }
  }

  Future<bool> _refreshSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _dio.post<dynamic>(
        _refreshPath,
        data: {'refresh_token': refreshToken},
        options: Options(
          extra: {
            _skipAuthHeaderExtra: true,
            _skipSessionRecoveryExtra: true,
          },
        ),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        return false;
      }
      final accessToken = body['access_token'] as String?;
      final nextRefreshToken = body['refresh_token'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          nextRefreshToken == null ||
          nextRefreshToken.isEmpty) {
        return false;
      }
      await _tokenStorage.writeAccessToken(accessToken);
      await _tokenStorage.writeRefreshToken(nextRefreshToken);
      return true;
    } on DioException {
      return false;
    } on FormatException {
      return false;
    }
  }
}
