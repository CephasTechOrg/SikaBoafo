import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/presentation/receive_repayment_screen.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

const _receivableId = 'test-recv-001';

const _stubDetail = LocalReceivableDetail(
  record: LocalReceivableRecord(
    receivableId: _receivableId,
    customerId: 'cust-001',
    customerName: 'Ama Owusu',
    originalAmount: '200.00',
    outstandingAmount: '120.00',
    status: 'open',
    syncStatus: 'applied',
    createdAtMillis: 0,
    dueDateIso: '2026-05-01',
  ),
  payments: [],
  customerPhoneNumber: '+233200000000',
);

Widget _buildScreen({
  LocalReceivableDetail? detail,
  bool simulateNotFound = false,
  Future<void> Function()? onRecordRepayment,
}) {
  return ProviderScope(
    overrides: [
      receivableDetailProvider(_receivableId).overrideWith(
        // Return null (not found) when simulateNotFound, else use detail or stub.
        (_) async => simulateNotFound ? null : (detail ?? _stubDetail),
      ),
      debtsControllerProvider.overrideWith(
        () => _FakeDebtsController(onRecordRepayment: onRecordRepayment),
      ),
    ],
    child: const MaterialApp(
      home: ReceiveRepaymentScreen(receivableId: _receivableId),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReceiveRepaymentScreen', () {
    testWidgets('displays customer name and outstanding balance', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Ama Owusu'), findsOneWidget);
      expect(find.text('GHS 120.00'), findsOneWidget);
      expect(find.text('Due 2026-05-01'), findsOneWidget);
    });

    testWidgets('shows Record Repayment form and Save Payment button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Record Repayment'), findsOneWidget);
      expect(find.text('Save Payment'), findsOneWidget);
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
    });

    testWidgets('pops with true on successful save', (tester) async {
      bool? poppedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receivableDetailProvider(_receivableId).overrideWith(
              (_) async => _stubDetail,
            ),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(onRecordRepayment: () async {}),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    poppedResult = await Navigator.of(ctx).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const ReceiveRepaymentScreen(
                          receivableId: _receivableId,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Save Payment'));
      await tester.pumpAndSettle();

      expect(poppedResult, isTrue);
    });

    testWidgets('shows SnackBar on error without popping', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          onRecordRepayment: () async =>
              throw ArgumentError('Amount must be greater than zero.'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Save Payment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
      // Screen is still visible — not popped
      expect(find.text('Save Payment'), findsOneWidget);
    });

    testWidgets('shows fallback card when detail is null', (tester) async {
      await tester.pumpWidget(_buildScreen(simulateNotFound: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Debt record not found.'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake controller
// ---------------------------------------------------------------------------

class _FakeDebtsController extends DebtsController {
  _FakeDebtsController({this.onRecordRepayment});

  final Future<void> Function()? onRecordRepayment;

  @override
  Future<DebtsViewData> build() async =>
      const DebtsViewData(customers: [], receivables: [], paidThisMonth: '0.00');

  @override
  Future<void> recordRepayment({
    required String receivableId,
    required String amount,
    required String paymentMethodLabel,
  }) async {
    final fn = onRecordRepayment;
    if (fn != null) {
      await fn();
    }
  }
}
