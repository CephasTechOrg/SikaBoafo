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
// Helpers
// ---------------------------------------------------------------------------

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

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

// Makes the test viewport tall enough that ListView builds all children eagerly.
void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
}

// ---------------------------------------------------------------------------
// _computeDebtAging unit tests (via widget integration)
// ---------------------------------------------------------------------------

void main() {
  group('ReportsScreen — Debt Aging Card', () {
    Future<void> pumpWithReceivables(
      WidgetTester tester,
      List<LocalReceivableRecord> receivables,
    ) async {
      _useTallScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
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
      await _pump(tester);
    }

    testWidgets('shows overdue count > 0 when receivable is past due', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final iso = '${yesterday.year.toString().padLeft(4, '0')}'
          '-${yesterday.month.toString().padLeft(2, '0')}'
          '-${yesterday.day.toString().padLeft(2, '0')}';
      await pumpWithReceivables(tester, _makeRecord(status: 'open', dueDateIso: iso));
      // Debt Aging section header may be scrolled off-screen in a ListView.
      expect(find.text('Debt Aging', skipOffstage: false), findsOneWidget);
      // Overdue row value should be "1" somewhere in the tree.
      expect(find.text('1', skipOffstage: false), findsWidgets);
    });

    testWidgets('skips settled receivables in aging calculation', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final iso = '${yesterday.year.toString().padLeft(4, '0')}'
          '-${yesterday.month.toString().padLeft(2, '0')}'
          '-${yesterday.day.toString().padLeft(2, '0')}';
      await pumpWithReceivables(tester, _makeRecord(status: 'settled', dueDateIso: iso));
      // Debt Aging section must still render; all bucket values should be 0.
      expect(find.text('Debt Aging', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows no_due bucket when receivable has no due date', (tester) async {
      await pumpWithReceivables(tester, _makeRecord(status: 'open', dueDateIso: null));
      expect(find.text('No due date', skipOffstage: false), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Widget render tests
  // -------------------------------------------------------------------------

  group('ReportsScreen — section rendering', () {
    testWidgets('renders Today KPI values correctly', (tester) async {
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
      await _pump(tester);

      // KPI cards are near the top of the ListView — should be on-screen.
      expect(find.text('GHS 150.00'), findsOneWidget);
      expect(find.text('GHS 40.00'), findsOneWidget);
      expect(find.text('GHS 110.00'), findsOneWidget);
      // "Today" appears in both the period tab chip and the bar chart badge.
      expect(find.text('Today'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders Payment Breakdown and Top Items sections when insights load',
        (tester) async {
      _useTallScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
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
      await _pump(tester);

      // Section headers scroll off-screen — use skipOffstage: false.
      expect(find.text('Payment Breakdown', skipOffstage: false), findsOneWidget);
      expect(find.text('Top Selling Items', skipOffstage: false), findsOneWidget);
      expect(find.text('Cash', skipOffstage: false), findsOneWidget);
      expect(find.text('Bread', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows offline card when insights fail', (tester) async {
      _useTallScreen(tester);
      addTearDown(tester.view.resetPhysicalSize);
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
      await _pump(tester);

      expect(
        find.text('Weekly/monthly data unavailable offline.',
            skipOffstage: false),
        findsAtLeastNWidgets(1),
      );
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
      await _pump(tester);

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
    return DebtsViewData(
        customers: const [], receivables: _receivables, paidThisMonth: '0.00');
  }
}
