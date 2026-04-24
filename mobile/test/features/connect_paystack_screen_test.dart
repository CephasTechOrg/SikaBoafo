import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/features/settings/data/settings_api.dart';
import 'package:biztrack_gh/features/settings/presentation/connect_paystack_screen.dart';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class _FakeSettingsApi extends SettingsApi {
  _FakeSettingsApi(this._state)
      : super(ApiClient(tokenStorage: _FakeSecureTokenStorage()));

  PaystackConnectionSettings _state;
  int saveCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<PaystackConnectionSettings> fetchPaystackConnection() async => _state;

  @override
  Future<PaystackConnectionSettings> savePaystackConnection({
    required String publicKey,
    required String mode,
    String? accountLabel,
  }) async {
    saveCalls += 1;
    _state = PaystackConnectionSettings(
      provider: 'paystack',
      isConnected: true,
      mode: mode,
      accountLabel: accountLabel,
      publicKeyMasked: publicKey.length <= 10
          ? publicKey
          : '${publicKey.substring(0, 6)}...${publicKey.substring(publicKey.length - 4)}',
    );
    return _state;
  }

  @override
  Future<PaystackConnectionSettings> disconnectPaystackConnection() async {
    disconnectCalls += 1;
    _state = PaystackConnectionSettings(
      provider: 'paystack',
      isConnected: false,
      mode: _state.mode,
      accountLabel: _state.accountLabel,
      publicKeyMasked: _state.publicKeyMasked,
    );
    return _state;
  }
}

Widget _buildScreen(_FakeSettingsApi fakeApi) {
  return ProviderScope(
    overrides: [
      paystackSettingsApiProvider.overrideWithValue(fakeApi),
    ],
    child: const MaterialApp(home: ConnectPaystackScreen()),
  );
}

void main() {
  testWidgets('shows disconnected status when paystack is not configured',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeApi = _FakeSettingsApi(
      const PaystackConnectionSettings(
        provider: 'paystack',
        isConnected: false,
        mode: 'test',
        accountLabel: null,
        publicKeyMasked: null,
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('Not Connected'), findsWidgets);
    expect(find.text('Save Paystack Settings'), findsOneWidget);
  });

  testWidgets('save then disconnect updates connection status', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeApi = _FakeSettingsApi(
      const PaystackConnectionSettings(
        provider: 'paystack',
        isConnected: false,
        mode: 'test',
        accountLabel: null,
        publicKeyMasked: null,
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Public key'),
      'pk_test_abcdefgh12345678',
    );
    final saveButton = find.text('Save Paystack Settings');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeApi.saveCalls, 1);
    expect(find.text('Connected'), findsWidgets);
    expect(find.text('Disconnect Paystack'), findsOneWidget);

    final disconnectButton = find.text('Disconnect Paystack');
    await tester.ensureVisible(disconnectButton);
    await tester.tap(disconnectButton);
    await tester.pumpAndSettle();

    expect(fakeApi.disconnectCalls, 1);
    expect(find.text('Not Connected'), findsWidgets);
  });
}
