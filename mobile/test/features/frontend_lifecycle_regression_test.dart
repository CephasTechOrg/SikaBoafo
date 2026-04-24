import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/presentation/debts_screen.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/inventory/providers/inventory_providers.dart';
import 'package:biztrack_gh/features/sales/data/sales_repository.dart';
import 'package:biztrack_gh/features/sales/presentation/sales_screen.dart';
import 'package:biztrack_gh/features/sales/providers/sales_providers.dart';

void main() {
  group('Frontend lifecycle regressions', () {
    testWidgets(
      'DebtsScreen does not throw when repayment completes after dispose',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final completer = Completer<void>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              debtsControllerProvider.overrideWith(
                () => _FakeDebtsController(
                  onRecordRepayment: () => completer.future,
                ),
              ),
            ],
            child: const MaterialApp(home: DebtsScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Record Payment').first);
        await tester.pumpAndSettle();

        final saveRepayment = find.text('Save Repayment');
        await tester.ensureVisible(saveRepayment);
        await tester.tap(saveRepayment);
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());

        completer.complete();
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'SalesScreen does not throw when sale save completes after dispose',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final completer = Completer<void>();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              inventoryControllerProvider.overrideWith(
                () => _FakeInventoryController(
                  seedItems: const [
                    LocalInventoryItem(
                      id: 'item-1',
                      name: 'Rice',
                      defaultPrice: '12.00',
                      quantityOnHand: 10,
                      isActive: true,
                    ),
                  ],
                ),
              ),
              salesControllerProvider.overrideWith(
                () =>
                    _FakeSalesController(onRecordSale: () => completer.future),
              ),
            ],
            child: const MaterialApp(home: SalesScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byIcon(Icons.add_rounded).first);
        await tester.pump();

        await tester.tap(find.text('Checkout'));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('Pay '));
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());

        completer.complete();
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _FakeDebtsController extends DebtsController {
  _FakeDebtsController({required this.onRecordRepayment});

  final Future<void> Function() onRecordRepayment;

  @override
  Future<DebtsViewData> build() async {
    return const DebtsViewData(
      customers: [
        LocalDebtCustomer(
          customerId: 'cust-1',
          name: 'Ama',
          totalOutstanding: '20.00',
        ),
      ],
      receivables: [
        LocalReceivableRecord(
          receivableId: 'recv-1',
          customerId: 'cust-1',
          customerName: 'Ama',
          originalAmount: '20.00',
          outstandingAmount: '20.00',
          status: 'open',
          syncStatus: 'applied',
          createdAtMillis: 0,
        ),
      ],
      paidThisMonth: '0.00',
    );
  }

  @override
  Future<void> recordRepayment({
    required String receivableId,
    required String amount,
    required String paymentMethodLabel,
  }) async {
    await onRecordRepayment();
  }
}

class _FakeInventoryController extends InventoryController {
  _FakeInventoryController({required this.seedItems});

  final List<LocalInventoryItem> seedItems;

  @override
  Future<List<LocalInventoryItem>> build() async => seedItems;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(seedItems);
  }
}

class _FakeSalesController extends SalesController {
  _FakeSalesController({required this.onRecordSale});

  final Future<void> Function() onRecordSale;

  @override
  Future<List<LocalSaleRecord>> build() async => const [];

  @override
  Future<void> refresh({bool? includeVoided}) async {
    state = const AsyncValue.data(<LocalSaleRecord>[]);
  }

  @override
  Future<void> recordSale({
    required String paymentMethodLabel,
    required List<SaleDraftLine> lines,
    String? note,
  }) async {
    await onRecordSale();
  }
}
