import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:biztrack_gh/app/app.dart';
import 'package:biztrack_gh/app/router.dart';
import 'package:biztrack_gh/core/services/biometric_service.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:biztrack_gh/features/dashboard/data/dashboard_api.dart';
import 'package:biztrack_gh/features/dashboard/providers/dashboard_providers.dart';
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/debts/providers/debts_providers.dart';
import 'package:biztrack_gh/features/expenses/data/expenses_repository.dart';
import 'package:biztrack_gh/features/expenses/providers/expenses_providers.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/inventory/providers/inventory_providers.dart';
import 'package:biztrack_gh/shared/providers/core_providers.dart';
import 'package:biztrack_gh/shared/providers/sync_providers.dart';

class _MemorySecureTokenStorage extends SecureTokenStorage {
  String? accessToken;
  String? refreshToken;
  bool biometricEnabled = false;
  DateTime? lastBiometricAt;
  DateTime? sessionGateCompletedAt;

  @override
  Future<void> writeAccessToken(String? value) async {
    accessToken = value;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<void> writeRefreshToken(String? value) async {
    refreshToken = value;
  }

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<bool> hasPersistedSession() async {
    return (refreshToken != null && refreshToken!.isNotEmpty) ||
        (accessToken != null && accessToken!.isNotEmpty);
  }

  @override
  Future<void> setBiometricEnabled(bool enabled) async {
    biometricEnabled = enabled;
  }

  @override
  Future<bool> isBiometricEnabled() async => biometricEnabled;

  @override
  Future<void> writeLastBiometricAt(DateTime? value) async {
    lastBiometricAt = value;
  }

  @override
  Future<DateTime?> readLastBiometricAt() async => lastBiometricAt;

  @override
  Future<void> markSessionGateComplete(DateTime? value) async {
    sessionGateCompletedAt = value;
  }

  @override
  Future<bool> hasCompletedSessionGate() async => sessionGateCompletedAt != null;

  @override
  Future<void> clearSessionGate() async {
    sessionGateCompletedAt = null;
  }

  @override
  Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    lastBiometricAt = null;
    sessionGateCompletedAt = null;
  }
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({
    required this.supported,
    this.authenticateResult = true,
  });

  final bool supported;
  final bool authenticateResult;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<BiometricAvailability> availability() async {
    return supported
        ? BiometricAvailability.available
        : BiometricAvailability.notSupported;
  }

  @override
  Future<bool> authenticate({required String reason}) async => authenticateResult;
}

class _FakeDebtsController extends DebtsController {
  _FakeDebtsController(this._receivables);

  final List<LocalReceivableRecord> _receivables;

  @override
  Future<DebtsViewData> build() async {
    return DebtsViewData(
      customers: const [
        LocalDebtCustomer(
          customerId: 'customer-1',
          name: 'Ama',
          totalOutstanding: '30.00',
        ),
      ],
      receivables: _receivables,
      paidThisMonth: '0.00',
    );
  }
}

class _FakeInventoryController extends InventoryController {
  @override
  Future<List<LocalInventoryItem>> build() async => const <LocalInventoryItem>[];
}

class _FakeExpensesController extends ExpensesController {
  @override
  Future<List<LocalExpenseRecord>> build() async => const <LocalExpenseRecord>[];
}

class _FakeSyncStatusController extends SyncStatusController {
  @override
  Future<SyncStatusSnapshot> build() async {
    return const SyncStatusSnapshot(
      backendReachable: true,
      isSyncing: false,
      stats: SyncQueueStats(
        pendingCount: 0,
        sendingCount: 0,
        failedCount: 0,
        conflictCount: 0,
        appliedCount: 0,
      ),
      failedEntries: <SyncQueueEntry>[],
      deadEntries: <SyncQueueEntry>[],
    );
  }

  @override
  Future<void> refreshStatus({bool attemptSync = false}) async {}
}

const _merchantContext = MerchantContext(
  businessName: 'Ama Ventures',
  businessType: 'Retail',
  storeName: 'Main Store',
  storeLocation: 'Accra',
  timezone: 'Africa/Accra',
);

const _summary = DashboardSummary(
  todaySalesTotal: '150.00',
  todayExpensesTotal: '40.00',
  todayEstimatedProfit: '110.00',
  todayGrossProfit: '0.00',
  debtOutstandingTotal: '200.00',
  lowStockCount: 3,
  timezone: 'Africa/Accra',
);

final _insights = DashboardInsights(
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
  monthlyPaymentBreakdown: const [
    DashboardPaymentBreakdown(
      paymentMethodLabel: 'cash',
      paymentMethodDisplay: 'Cash',
      totalAmount: '1200.00',
      saleCount: 10,
    ),
    DashboardPaymentBreakdown(
      paymentMethodLabel: 'mobile_money',
      paymentMethodDisplay: 'Mobile Money',
      totalAmount: '800.00',
      saleCount: 5,
    ),
  ],
  monthlyTopSellingItems: const [
    DashboardTopSellingItem(
      itemId: 'item-1',
      itemName: 'Bread',
      quantitySold: 50,
      salesTotal: '250.00',
    ),
  ],
);

const _overlay = LocalDashboardOverlay(
  todayPendingSalesMinor: 0,
  todayPendingSalesCount: 0,
  todayPendingExpensesMinor: 0,
  monthPendingSalesMinor: 0,
  monthPendingExpensesMinor: 0,
  monthPendingPaymentMinorByMethod: <String, int>{},
  monthPendingTopSelling: <LocalTopSellingOverlayRow>[],
  lowStockCountLocal: 0,
  debtOutstandingMinorLocal: 0,
);

final _receivables = <LocalReceivableRecord>[
  const LocalReceivableRecord(
    receivableId: 'recv-1',
    customerId: 'customer-1',
    customerName: 'Ama',
    originalAmount: '30.00',
    outstandingAmount: '30.00',
    status: 'open',
    syncStatus: 'applied',
    createdAtMillis: 0,
  ),
];

Future<void> _pumpApp(
  WidgetTester tester, {
  required _MemorySecureTokenStorage storage,
  _FakeBiometricService? biometricService,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        secureTokenStorageProvider.overrideWithValue(storage),
        biometricServiceProvider.overrideWithValue(
          biometricService ??
              _FakeBiometricService(supported: true, authenticateResult: true),
        ),
        merchantContextProvider.overrideWith((_) async => _merchantContext),
        dashboardSummaryProvider.overrideWith((_) async => _summary),
        dashboardRecentActivityProvider.overrideWith(
          (_) async => const <DashboardActivity>[],
        ),
        dashboardInsightsProvider.overrideWith((_) async => _insights),
        localDashboardOverlayProvider.overrideWith((_) async => _overlay),
        localPendingActivityProvider.overrideWith(
          (_) async => const <LocalPendingActivityRow>[],
        ),
        debtsControllerProvider.overrideWith(
          () => _FakeDebtsController(_receivables),
        ),
        inventoryControllerProvider.overrideWith(_FakeInventoryController.new),
        expensesControllerProvider.overrideWith(_FakeExpensesController.new),
        syncStatusControllerProvider.overrideWith(_FakeSyncStatusController.new),
      ],
      child: const BizTrackApp(),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'unauthenticated protected route redirects through Splash and ends on Auth',
    (tester) async {
      final storage = _MemorySecureTokenStorage();
      await _pumpApp(tester, storage: storage);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BizTrackApp)),
      );
      container.read(appRouterProvider).go(AppRoute.debts.path);
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    },
  );

  testWidgets(
    'authenticated protected route opens the requested destination',
    (tester) async {
      final storage = _MemorySecureTokenStorage()
        ..refreshToken = 'refresh-token'
        ..sessionGateCompletedAt = DateTime.now();
      await _pumpApp(tester, storage: storage);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BizTrackApp)),
      );
      container.read(appRouterProvider).go(AppRoute.reports.path);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Reports'), findsWidgets);
      expect(find.text('Payment Breakdown', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets(
    'biometric-enabled session with unavailable biometrics is sent to Auth',
    (tester) async {
      final storage = _MemorySecureTokenStorage()
        ..refreshToken = 'refresh-token'
        ..biometricEnabled = true;
      await _pumpApp(
        tester,
        storage: storage,
        biometricService: _FakeBiometricService(supported: false),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(BizTrackApp)),
      );
      container.read(appRouterProvider).go(AppRoute.home.path);
      await tester.pump();

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    },
  );

  testWidgets('dashboard Collect Debt quick action opens Debts', (tester) async {
    final storage = _MemorySecureTokenStorage()
      ..refreshToken = 'refresh-token'
      ..sessionGateCompletedAt = DateTime.now();
    await _pumpApp(tester, storage: storage);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BizTrackApp)),
    );
    container.read(appRouterProvider).go(AppRoute.home.path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Collect Debt'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Debts'), findsWidgets);
    expect(find.text('Recent Debts'), findsOneWidget);
  });

  testWidgets('Debts Reports actions open Reports', (tester) async {
    final storage = _MemorySecureTokenStorage()
      ..refreshToken = 'refresh-token'
      ..sessionGateCompletedAt = DateTime.now();
    await _pumpApp(tester, storage: storage);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BizTrackApp)),
    );
    container.read(appRouterProvider).go(AppRoute.debts.path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Reports').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Reports'), findsWidgets);
    expect(find.text('Payment Breakdown', skipOffstage: false), findsOneWidget);
  });
}
