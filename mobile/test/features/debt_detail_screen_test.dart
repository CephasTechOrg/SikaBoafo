import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/debts/data/debts_payments_api.dart';
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/presentation/debt_detail_screen.dart';
import 'package:biztrack_gh/features/debts/providers/debt_detail_provider.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';

const _receivableId = 'recv-001';

/// Mutable detail snapshot so [receivableDetailProvider] can reflect link flow.
class _ReceivableDetailHarness {
  static bool paymentLinkActive = false;

  static LocalReceivableRecord get receivable => LocalReceivableRecord(
        receivableId: _receivableId,
        customerId: 'cust-001',
        customerName: 'Ama Owusu',
        originalAmount: '120.00',
        outstandingAmount: '120.00',
        status: 'open',
        syncStatus: 'applied',
        createdAtMillis: 0,
        paymentLink: paymentLinkActive ? 'https://checkout.paystack.com/abc123' : null,
        paymentId: paymentLinkActive ? 'pay-1' : null,
        paymentAmount: paymentLinkActive ? '120.00' : null,
      );

  static LocalDebtCustomer get customer => const LocalDebtCustomer(
        customerId: 'cust-001',
        name: 'Ama Owusu',
        totalOutstanding: '120.00',
        syncStatus: 'applied',
        createdAtMillis: 0,
        phoneNumber: '0244123456',
      );

  static LocalReceivableDetail get detail => LocalReceivableDetail(
        receivable: receivable,
        customer: customer,
        payments: const [],
      );
}

class _FakeDebtsController extends DebtsController {
  int initiateCalls = 0;
  int refreshCalls = 0;

  /// When set, the next `refreshFromServer` call will surface this string via
  /// `DebtsViewData.lastSyncError` so detail-screen tests can assert the
  /// "Sync paused" SnackBar plumbing without hitting the network.
  String? nextRefreshError;

  @override
  Future<DebtsViewData> build() async {
    final d = _ReceivableDetailHarness.detail;
    return DebtsViewData(
      customers: [d.customer],
      receivables: [d.receivable],
    );
  }

  @override
  Future<void> refreshFromServer() async {
    refreshCalls += 1;
    final d = _ReceivableDetailHarness.detail;
    state = AsyncValue.data(
      DebtsViewData(
        customers: [d.customer],
        receivables: [d.receivable],
        lastSyncError: nextRefreshError,
      ),
    );
  }

  @override
  Future<void> ensureReceivableCreateSyncedToBackend(String receivableId) async {}

  @override
  Future<LocalReceivableRecord?> getReceivableById(String receivableId) async {
    return _ReceivableDetailHarness.detail.receivable;
  }

  @override
  Future<ReceivablePaymentInitiationDto> initiatePaymentLink({
    required String receivableId,
    String? amount,
  }) async {
    initiateCalls += 1;
    _ReceivableDetailHarness.paymentLinkActive = true;
    state = AsyncValue.data(await build());
    return const ReceivablePaymentInitiationDto(
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

Widget _buildScreen(_FakeDebtsController controller) {
  return ProviderScope(
    overrides: [
      debtsControllerProvider.overrideWith(() => controller),
      receivableDetailProvider(_receivableId).overrideWith((ref) async {
        ref.watch(debtsControllerProvider);
        return _ReceivableDetailHarness.detail;
      }),
    ],
    child: const MaterialApp(
      home: DebtDetailScreen(receivableId: _receivableId),
    ),
  );
}

void main() {
  testWidgets(
    'Share link calls initiatePaymentLink after expanding Collect online',
    (tester) async {
      _ReceivableDetailHarness.paymentLinkActive = false;
      addTearDown(() {
        _ReceivableDetailHarness.paymentLinkActive = false;
      });

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeController = _FakeDebtsController();

      await tester.pumpWidget(_buildScreen(fakeController));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Share link'), findsNothing);

      await tester.tap(find.text('Collect online'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Share link'), findsOneWidget);
      expect(
        find.text('Payment link active', skipOffstage: false),
        findsNothing,
      );

      await tester.tap(find.text('Share link'));
      await tester.pump();

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (fakeController.initiateCalls >= 1) break;
      }

      expect(fakeController.initiateCalls, 1);
    },
  );

  testWidgets(
    'tapping app bar refresh surfaces lastSyncError via SnackBar',
    (tester) async {
      _ReceivableDetailHarness.paymentLinkActive = false;
      addTearDown(() {
        _ReceivableDetailHarness.paymentLinkActive = false;
      });

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeController = _FakeDebtsController()
        ..nextRefreshError = 'Backend unreachable';

      await tester.pumpWidget(_buildScreen(fakeController));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fakeController.refreshCalls, 1);
      expect(
        find.text('Sync paused: Backend unreachable'),
        findsOneWidget,
      );
    },
  );
}
