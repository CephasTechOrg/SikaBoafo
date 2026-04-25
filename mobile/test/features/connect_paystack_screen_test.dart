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
  String? lastPublicKey;
  String? lastSecretKey;
  String? lastMode;

  @override
  Future<PaystackConnectionSettings> fetchPaystackConnection() async => _state;

  @override
  Future<PaystackConnectionSettings> savePaystackConnection({
    String? publicKey,
    String? secretKey,
    required String mode,
    String? accountLabel,
  }) async {
    saveCalls += 1;
    lastPublicKey = publicKey;
    lastSecretKey = secretKey;
    lastMode = mode;
    _state = PaystackConnectionSettings(
      provider: 'paystack',
      isConnected: true,
      mode: mode,
      accountLabel: accountLabel,
      test: mode == 'test'
          ? const PaystackModeState(
              configured: true,
              publicKeyMasked: 'pk_tes...5678',
              secretKeyMasked: 'sk_test_...5678',
            )
          : _state.test,
      live: mode == 'live'
          ? const PaystackModeState(
              configured: true,
              publicKeyMasked: 'pk_liv...5678',
              secretKeyMasked: 'sk_live_...5678',
            )
          : _state.live,
    );
    return _state;
  }

  @override
  Future<PaystackConnectionSettings> disconnectPaystackConnection() async {
    disconnectCalls += 1;
    _state = const PaystackConnectionSettings(
      provider: 'paystack',
      isConnected: false,
      mode: 'test',
      accountLabel: null,
      test: PaystackModeState(configured: false),
      live: PaystackModeState(configured: false),
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
        test: PaystackModeState(configured: false),
        live: PaystackModeState(configured: false),
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('Not Connected'), findsWidgets);
    expect(find.text('Save & Verify'), findsOneWidget);
  });

  testWidgets('requires secret key for unconfigured selected mode',
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
        test: PaystackModeState(configured: false),
        live: PaystackModeState(configured: false),
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    final saveButton = find.text('Save & Verify');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeApi.saveCalls, 0);
    expect(find.text('Secret key is required to connect this mode for the first time.'),
        findsOneWidget);
  });

  testWidgets('saves credentials successfully', (tester) async {
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
        test: PaystackModeState(configured: false),
        live: PaystackModeState(configured: false),
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Public key (optional)'),
      'pk_test_abcdefgh12345678',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Secret key'),
      'sk_test_abcdefgh12345678',
    );
    final saveButton = find.text('Save & Verify');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(fakeApi.saveCalls, 1);
    expect(fakeApi.lastPublicKey, 'pk_test_abcdefgh12345678');
    expect(fakeApi.lastSecretKey, 'sk_test_abcdefgh12345678');
    expect(find.text('Connected'), findsWidgets);
  });

  testWidgets('disconnect shows confirmation dialog and disconnects', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Start in the connected state so we can test the disconnect flow directly
    final fakeApi = _FakeSettingsApi(
      const PaystackConnectionSettings(
        provider: 'paystack',
        isConnected: true,
        mode: 'test',
        accountLabel: null,
        test: PaystackModeState(
          configured: true,
          publicKeyMasked: 'pk_tes...5678',
          secretKeyMasked: 'sk_test_...5678',
        ),
        live: PaystackModeState(configured: false),
      ),
    );

    await tester.pumpWidget(_buildScreen(fakeApi));
    await tester.pumpAndSettle();

    expect(find.text('Connected'), findsWidgets);
    expect(find.text('Disconnect Paystack'), findsOneWidget);

    final disconnectButton = find.text('Disconnect Paystack');
    await tester.ensureVisible(disconnectButton);
    await tester.tap(disconnectButton);
    await tester.pumpAndSettle();

    // _DisconnectConfirmDialog should now be showing
    expect(
      find.byKey(const Key('disconnect_confirm_input')),
      findsOneWidget,
      reason: 'Disconnect confirmation dialog should appear after tapping button',
    );
    await tester.enterText(
      find.byKey(const Key('disconnect_confirm_input')),
      'DISCONNECT',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(fakeApi.disconnectCalls, 1);
    expect(find.text('Not Connected'), findsWidgets);
  });
}
