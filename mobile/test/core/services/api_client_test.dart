import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  String? accessToken;
  String? refreshToken;
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<void> writeAccessToken(String? value) async {
    accessToken = value;
  }

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> writeRefreshToken(String? value) async {
    refreshToken = value;
  }

  @override
  Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    cleared = true;
  }
}

class _Always401Adapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"detail":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
      statusMessage: 'Unauthorized',
    );
  }
}

class _RefreshSuccessAdapter implements HttpClientAdapter {
  int summaryCalls = 0;
  int refreshCalls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls += 1;
      final payload = options.data as Map<String, dynamic>? ?? const {};
      if (payload['refresh_token'] == 'valid-refresh') {
        return ResponseBody.fromString(
          '{"access_token":"new-access","refresh_token":"new-refresh"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
      return ResponseBody.fromString(
        '{"detail":"Invalid refresh token."}',
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
        statusMessage: 'Unauthorized',
      );
    }

    if (options.path == '/reports/summary') {
      summaryCalls += 1;
      final authHeader = options.headers['Authorization'];
      if (authHeader == 'Bearer new-access') {
        return ResponseBody.fromString(
          '{"status":"ok"}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }
    }

    return ResponseBody.fromString(
      '{"detail":"Unauthorized"}',
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
      statusMessage: 'Unauthorized',
    );
  }
}

void main() {
  test(
      '401 on protected endpoint clears session and triggers unauthorized callback once when refresh is unavailable',
      () async {
    final storage = _FakeSecureTokenStorage()..accessToken = 'valid-token';
    var unauthorizedCalls = 0;

    final dio = Dio();
    dio.httpClientAdapter = _Always401Adapter();

    final apiClient = ApiClient(
      tokenStorage: storage,
      dio: dio,
      onUnauthorized: () async {
        unauthorizedCalls += 1;
      },
    );

    await expectLater(
      apiClient.dio.get<dynamic>('/reports/summary'),
      throwsA(isA<DioException>()),
    );

    expect(storage.cleared, isTrue);
    expect(storage.accessToken, isNull);
    expect(unauthorizedCalls, 1);
  });

  test('401 on protected endpoint refreshes tokens and retries once', () async {
    final storage = _FakeSecureTokenStorage()
      ..accessToken = 'expired-access'
      ..refreshToken = 'valid-refresh';
    var unauthorizedCalls = 0;

    final adapter = _RefreshSuccessAdapter();
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final apiClient = ApiClient(
      tokenStorage: storage,
      dio: dio,
      onUnauthorized: () async {
        unauthorizedCalls += 1;
      },
    );

    final response = await apiClient.dio.get<dynamic>('/reports/summary');

    expect(response.statusCode, 200);
    expect(adapter.summaryCalls, 2);
    expect(adapter.refreshCalls, 1);
    expect(storage.cleared, isFalse);
    expect(storage.accessToken, 'new-access');
    expect(storage.refreshToken, 'new-refresh');
    expect(unauthorizedCalls, 0);
  });

  test(
      '401 on /auth endpoint does not clear session or trigger unauthorized callback',
      () async {
    final storage = _FakeSecureTokenStorage()..accessToken = 'valid-token';
    var unauthorizedCalls = 0;

    final dio = Dio();
    dio.httpClientAdapter = _Always401Adapter();

    final apiClient = ApiClient(
      tokenStorage: storage,
      dio: dio,
      onUnauthorized: () async {
        unauthorizedCalls += 1;
      },
    );

    await expectLater(
      apiClient.dio.post<dynamic>('/auth/pin/login',
          data: {'phone_number': '+233000000000'}),
      throwsA(isA<DioException>()),
    );

    expect(storage.cleared, isFalse);
    expect(storage.accessToken, isNotNull);
    expect(unauthorizedCalls, 0);
  });

  test(
      '401 without Authorization header does not clear session or trigger unauthorized callback',
      () async {
    final storage = _FakeSecureTokenStorage();
    var unauthorizedCalls = 0;

    final dio = Dio();
    dio.httpClientAdapter = _Always401Adapter();

    final apiClient = ApiClient(
      tokenStorage: storage,
      dio: dio,
      onUnauthorized: () async {
        unauthorizedCalls += 1;
      },
    );

    await expectLater(
      apiClient.dio.get<dynamic>('/reports/recent-activity'),
      throwsA(isA<DioException>()),
    );

    expect(storage.cleared, isFalse);
    expect(unauthorizedCalls, 0);
  });
}
