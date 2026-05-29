import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/features/debts/data/debts_api.dart';
import 'package:biztrack_gh/features/debts/data/debts_payments_api.dart';
import 'package:biztrack_gh/features/debts/presentation/widgets/debt_paystack_qr_sheet.dart';
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';
import 'package:biztrack_gh/shared/providers/sync_providers.dart';

const _receivableId = 'recv-debt01';
const _paymentId = 'pay-debt01';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

/// Simulates webhook-delay: [fetchReceivable] still shows open while
/// [verifyPayment] returns the settled state the mobile app must trust.
class _StaleFetchDebtsApi extends DebtsApi {
  _StaleFetchDebtsApi() : super(_api());

  static ApiClient _api() =>
      ApiClient(tokenStorage: _FakeSecureTokenStorage(), dio: Dio());

  int fetchCalls = 0;

  @override
  Future<ReceivableDto> fetchReceivable(String receivableId) async {
    fetchCalls += 1;
    return _staleOpen;
  }
}

class _SettledVerifyDebtsPaymentsApi extends DebtsPaymentsApi {
  _SettledVerifyDebtsPaymentsApi() : super(_StaleFetchDebtsApi._api());

  int verifyCalls = 0;

  @override
  Future<ReceivablePaymentVerifyOutDto> verifyPayment(String paymentId) async {
    verifyCalls += 1;
    return _settledVerify;
  }
}

class _FakeDebtsController extends DebtsController {
  ReceivableDto? lastApplied;

  @override
  Future<DebtsViewData> build() async {
    return DebtsViewData(customers: [], receivables: []);
  }

  @override
  Future<void> applyServerReceivable(ReceivableDto dto) async {
    lastApplied = dto;
  }

  @override
  Future<void> refreshFromServer() async {}
}

const _staleOpen = ReceivableDto(
  receivableId: _receivableId,
  customerId: 'cust-1',
  customerName: 'Ama Owusu',
  originalAmount: '120.00',
  outstandingAmount: '120.00',
  status: 'open',
  createdAtIso: '2026-01-01T00:00:00Z',
);

const _settledVerify = ReceivablePaymentVerifyOutDto(
  paymentId: _paymentId,
  receivableId: _receivableId,
  providerPaymentStatus: 'succeeded',
  receivableStatus: 'settled',
  outstandingAmount: '0.00',
  paystackTransactionStatus: 'success',
);

void main() {
  testWidgets(
    'DEBT-01: auto-poll calls verify when fetch still shows open, then completes',
    (tester) async {
      final fakeDebtsApi = _StaleFetchDebtsApi();
      final fakePaymentsApi = _SettledVerifyDebtsPaymentsApi();
      final fakeController = _FakeDebtsController();
      var confirmed = false;
      ReceivableDto? confirmedRow;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            debtsApiProvider.overrideWithValue(fakeDebtsApi),
            debtsPaymentsApiProvider.overrideWithValue(fakePaymentsApi),
            debtsControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DebtPaystackQrSheet(
                receivableId: _receivableId,
                checkoutUrl: 'https://checkout.paystack.com/test',
                paymentId: _paymentId,
                amountDisplay: 'GHS 120.00',
                customerName: 'Ama Owusu',
                onPaymentConfirmed: (row) {
                  confirmed = true;
                  confirmedRow = row;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Waiting for payment'), findsOneWidget);
      expect(confirmed, isFalse);

      // Sheet polls every 3s — advance past one tick.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(fakeDebtsApi.fetchCalls, greaterThanOrEqualTo(1));
      expect(fakePaymentsApi.verifyCalls, greaterThanOrEqualTo(1));
      expect(confirmed, isTrue);
      expect(confirmedRow?.status, 'settled');
    },
  );

  testWidgets(
    'DEBT-01: auto-poll completes when fetch already shows settled (webhook first)',
    (tester) async {
      final fakeController = _FakeDebtsController();
      var confirmed = false;

      final settledFetchApi = _SettledOnFetchDebtsApi();
      final noopPaymentsApi = _NoopDebtsPaymentsApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            debtsApiProvider.overrideWithValue(settledFetchApi),
            debtsPaymentsApiProvider.overrideWithValue(noopPaymentsApi),
            debtsControllerProvider.overrideWith(() => fakeController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DebtPaystackQrSheet(
                receivableId: _receivableId,
                checkoutUrl: 'https://checkout.paystack.com/test',
                paymentId: _paymentId,
                amountDisplay: 'GHS 120.00',
                customerName: 'Ama Owusu',
                onPaymentConfirmed: (_) => confirmed = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(settledFetchApi.fetchCalls, greaterThanOrEqualTo(1));
      expect(noopPaymentsApi.verifyCalls, 0);
      expect(confirmed, isTrue);
    },
  );
}

class _SettledOnFetchDebtsApi extends DebtsApi {
  _SettledOnFetchDebtsApi() : super(_StaleFetchDebtsApi._api());

  int fetchCalls = 0;

  @override
  Future<ReceivableDto> fetchReceivable(String receivableId) async {
    fetchCalls += 1;
    return const ReceivableDto(
      receivableId: _receivableId,
      customerId: 'cust-1',
      customerName: 'Ama Owusu',
      originalAmount: '120.00',
      outstandingAmount: '0.00',
      status: 'settled',
      createdAtIso: '2026-01-01T00:00:00Z',
    );
  }
}

class _NoopDebtsPaymentsApi extends DebtsPaymentsApi {
  _NoopDebtsPaymentsApi() : super(_StaleFetchDebtsApi._api());

  int verifyCalls = 0;

  @override
  Future<ReceivablePaymentVerifyOutDto> verifyPayment(String paymentId) async {
    verifyCalls += 1;
    throw StateError('verify should not run when fetch already settled');
  }
}
