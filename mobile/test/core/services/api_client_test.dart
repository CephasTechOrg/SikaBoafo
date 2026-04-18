import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  String? accessToken;
  bool cleared = false;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<void> clearSession() async {
    accessToken = null;
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

void main() {
  test(
      '401 on protected endpoint clears session and triggers unauthorized callback once',
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
