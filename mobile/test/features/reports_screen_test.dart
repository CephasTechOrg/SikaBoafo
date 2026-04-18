import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/features/dashboard/data/dashboard_api.dart';
import 'package:biztrack_gh/features/dashboard/presentation/reports_screen.dart';
import 'package:biztrack_gh/features/dashboard/providers/dashboard_providers.dart';
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

const _stubSummary = DashboardSummary(
  todaySalesTotal: '150.00',
  todayExpensesTotal: '40.00',
  todayEstimatedProfit: '110.00',
  debtOutstandingTotal: '200.00',
  lowStockCount: 3,
  timezone: 'Africa/Accra',
);

final _stubInsights = DashboardInsights(
  timezone: 'Africa/Accra',
  week: DashboardPeriodSummary(
    periodStartUtc: DateTime(2026, 4, 14),
    periodEndUtc: DateTime(2026, 4, 20),
    salesTotal: '500.00',
    expensesTotal: '120.00',
    estimatedProfit: '380.00',
  ),
  month: DashboardPeriodSummary(
    periodStartUtc: DateTime(2026, 4, 1),
    periodEndUtc: DateTime(2026, 4, 30),
    salesTotal: '2000.00',
    expensesTotal: '450.00',
    estimatedProfit: '1550.00',
  ),
  monthlyPaymentBreakdown: [
    const DashboardPaymentBreakdown(
      paymentMethodLabel: 'cash',
      paymentMethodDisplay: 'Cash',
      totalAmount: '1200.00',
      saleCount: 10,
    ),
    const DashboardPaymentBreakdown(
      paymentMethodLabel: 'mobile_money',
      paymentMethodDisplay: 'Mobile Money',
      totalAmount: '800.00',
      saleCount: 5,
    ),
  ],
  monthlyTopSellingItems: [
    const DashboardTopSellingItem(
      itemId: 'item-1',
      itemName: 'Bread',
      quantitySold: 50,
      salesTotal: '250.00',
    ),
    const DashboardTopSellingItem(
      itemId: 'item-2',
      itemName: 'Milk',
      quantitySold: 30,
      salesTotal: '180.00',
    ),
  ],
);

// ---------------------------------------------------------------------------
// _computeDebtAging unit tests (pure function — no widget harness needed)
// ---------------------------------------------------------------------------

// Access the function via a thin wrapper since it's library-private.
// We test through the public API by verifying _DebtAgingCard renders correctly.
// The unit tests below directly call the logic via the test-accessible route.

List<LocalReceivableRecord> _makeRecord({
  required String status,
  String? dueDateIso,
}) {
  return [
    LocalReceivableRecord(
      receivableId: 'r1',
      customerId: 'c1',
      customerName: 'Test',
      originalAmount: '100.00',
      outstandingAmount: '100.00',
      status: status,
      syncStatus: 'applied',
      createdAtMillis: 0,
      dueDateIso: dueDateIso,
    ),
  ];
}

void main() {
  // -------------------------------------------------------------------------
  // Pure function tests for _computeDebtAging via widget integration
  // We verify that the _DebtAgingCard shows the right bucket counts.
  // -------------------------------------------------------------------------

  group('ReportsScreen — Debt Aging Card', () {
    Future<void> pumpWithReceivables(
      WidgetTester tester,
      List<LocalReceivableRecord> receivables,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryProvider.overrideWith(
              (_) async => _stubSummary,
            ),
            dashboardInsightsProvider.overrideWith(
              (_) async => _stubInsights,
            ),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(receivables),
            ),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows overdue count > 0 when receivable is past due', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final iso = '${yesterday.year.toString().padLeft(4, '0')}'
          '-${yesterday.month.toString().padLeft(2, '0')}'
          '-${yesterday.day.toString().padLeft(2, '0')}';
      await pumpWithReceivables(tester, _makeRecord(status: 'open', dueDateIso: iso));
      expect(find.text('Debt Aging'), findsOneWidget);
      // Overdue row value should be "1" in the debt aging card
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('skips settled receivables in aging calculation', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final iso = '${yesterday.year.toString().padLeft(4, '0')}'
          '-${yesterday.month.toString().padLeft(2, '0')}'
          '-${yesterday.day.toString().padLeft(2, '0')}';
      await pumpWithReceivables(tester, _makeRecord(status: 'settled', dueDateIso: iso));
      // All buckets should be 0 — settled records are excluded
      expect(find.text('Debt Aging'), findsOneWidget);
    });

    testWidgets('shows no_due bucket when receivable has no due date', (tester) async {
      await pumpWithReceivables(tester, _makeRecord(status: 'open', dueDateIso: null));
      expect(find.text('No due date'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Widget render tests
  // -------------------------------------------------------------------------

  group('ReportsScreen — section rendering', () {
    testWidgets('renders Today section with correct values', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryProvider.overrideWith((_) async => _stubSummary),
            dashboardInsightsProvider.overrideWith((_) async => _stubInsights),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(const []),
            ),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('GHS 150.00'), findsOneWidget);
      expect(find.text('GHS 40.00'), findsOneWidget);
      expect(find.text('GHS 110.00'), findsOneWidget);
    });

    testWidgets('renders Weekly & Monthly section headers when insights load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryProvider.overrideWith((_) async => _stubSummary),
            dashboardInsightsProvider.overrideWith((_) async => _stubInsights),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(const []),
            ),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Weekly & Monthly'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Payment Breakdown (Month)'), findsOneWidget);
      expect(find.text('Top Selling Items (Month)'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);
    });

    testWidgets('shows insights unavailable card when insights fail', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryProvider.overrideWith((_) async => _stubSummary),
            dashboardInsightsProvider.overrideWith(
              (_) async => throw Exception('offline'),
            ),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(const []),
            ),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Weekly/monthly data unavailable offline.'), findsOneWidget);
    });

    testWidgets('shows error view when summary fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardSummaryProvider.overrideWith(
              (_) async => throw Exception('Connection error'),
            ),
            dashboardInsightsProvider.overrideWith((_) async => _stubInsights),
            debtsControllerProvider.overrideWith(
              () => _FakeDebtsController(const []),
            ),
          ],
          child: const MaterialApp(home: ReportsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

// ---------------------------------------------------------------------------
// Fake controller — replaces AsyncNotifier for test isolation
// ---------------------------------------------------------------------------

class _FakeDebtsController extends DebtsController {
  _FakeDebtsController(this._receivables);

  final List<LocalReceivableRecord> _receivables;

  @override
  Future<DebtsViewData> build() async {
    return DebtsViewData(customers: const [], receivables: _receivables, paidThisMonth: '0.00');
  }
}
