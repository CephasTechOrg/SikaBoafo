import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/features/debts/data/debts_api.dart';
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/presentation/debt_detail_screen.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';
import 'package:biztrack_gh/shared/providers/sync_providers.dart';

const _receivableId = 'recv-001';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class _FakeDebtsApi extends DebtsApi {
  _FakeDebtsApi() : super(ApiClient(tokenStorage: _FakeSecureTokenStorage()));

  int initiateCalls = 0;
  String? generatedLink;

  @override
  Future<PaymentInitiationDto> initiateReceivablePaymentLink(
    String receivableId,
  ) async {
    initiateCalls += 1;
    generatedLink = 'https://checkout.paystack.com/abc123';
    return const PaymentInitiationDto(
      paymentId: 'pay-1',
      provider: 'paystack',
      providerReference: 'PSK_REF_1',
      checkoutUrl: 'https://checkout.paystack.com/abc123',
      amount: '120.00',
      currency: 'GHS',
      status: 'pending',
      receivableId: _receivableId,
      accessCode: 'ACCESS_1',
    );
  }
}

class _FakeDebtsController extends DebtsController {
  int refreshCalls = 0;

  @override
  Future<DebtsViewData> build() async {
    return const DebtsViewData(
      customers: [],
      receivables: [
        LocalReceivableRecord(
          receivableId: _receivableId,
          customerId: 'cust-001',
          customerName: 'Ama Owusu',
          originalAmount: '120.00',
          outstandingAmount: '120.00',
          status: 'open',
          syncStatus: 'applied',
          createdAtMillis: 0,
        ),
      ],
      paidThisMonth: '0.00',
    );
  }

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    state = await AsyncValue.guard(build);
  }
}

LocalReceivableDetail _detailForLink(String? link) {
  return LocalReceivableDetail(
    record: LocalReceivableRecord(
      receivableId: _receivableId,
      customerId: 'cust-001',
      customerName: 'Ama Owusu',
      originalAmount: '120.00',
      outstandingAmount: '120.00',
      status: 'open',
      syncStatus: 'applied',
      createdAtMillis: 0,
      paymentLink: link,
    ),
    payments: const [],
    customerPhoneNumber: '0244123456',
  );
}

Widget _buildScreen({
  required _FakeDebtsApi debtsApi,
  required _FakeDebtsController debtsController,
}) {
  return ProviderScope(
    overrides: [
      debtsApiProvider.overrideWithValue(debtsApi),
      debtsControllerProvider.overrideWith(() => debtsController),
      receivableDetailProvider(_receivableId).overrideWith(
        (_) async => _detailForLink(debtsApi.generatedLink),
      ),
    ],
    child: const MaterialApp(
      home: DebtDetailScreen(receivableId: _receivableId),
    ),
  );
}

void main() {
  testWidgets('generate link action initiates payment and reveals link panel',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeApi = _FakeDebtsApi();
    final fakeController = _FakeDebtsController();

    await tester.pumpWidget(
      _buildScreen(
        debtsApi: fakeApi,
        debtsController: fakeController,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generate Link'), findsOneWidget);
    expect(find.text('Payment link ready'), findsNothing);

    await tester.tap(find.text('Generate Link'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(fakeApi.initiateCalls, 1);
    expect(fakeController.refreshCalls, 1);
    expect(find.text('Payment link ready'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);
  });
}

