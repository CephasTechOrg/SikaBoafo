import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../data/dashboard_api.dart';

class LocalDashboardOverlay {
  const LocalDashboardOverlay({
    required this.todayPendingSalesMinor,
    required this.todayPendingSalesCount,
    required this.todayPendingExpensesMinor,
    required this.monthPendingSalesMinor,
    required this.monthPendingExpensesMinor,
    required this.monthPendingPaymentMinorByMethod,
    required this.monthPendingTopSelling,
    required this.lowStockCountLocal,
    required this.debtOutstandingMinorLocal,
  });

  final int todayPendingSalesMinor;
  final int todayPendingSalesCount;
  final int todayPendingExpensesMinor;

  final int monthPendingSalesMinor;
  final int monthPendingExpensesMinor;

  /// payment_method_label -> amount minor (pending only)
  final Map<String, int> monthPendingPaymentMinorByMethod;

  final List<LocalTopSellingOverlayRow> monthPendingTopSelling;

  final int lowStockCountLocal;
  final int debtOutstandingMinorLocal;

  bool get hasPendingSales => todayPendingSalesMinor > 0;
}

class LocalTopSellingOverlayRow {
  const LocalTopSellingOverlayRow({
    required this.itemId,
    required this.itemName,
    required this.quantitySold,
    required this.salesTotalMinor,
  });

  final String itemId;
  final String itemName;
  final int quantitySold;
  final int salesTotalMinor;
}

class LocalPendingActivityRow {
  const LocalPendingActivityRow({
    required this.activityType,
    required this.title,
    required this.detail,
    required this.amount,
    required this.createdAt,
    this.itemId,
    this.itemName,
  });

  final String activityType; // 'sale' | 'expense'
  final String title;
  final String detail;
  final String amount;
  final DateTime createdAt;
  final String? itemId;
  final String? itemName;
}

final dashboardApiProvider = Provider<DashboardApi>((ref) {
  return DashboardApi(
    ref.watch(apiClientProvider),
    cache: KvCacheRepository(ref.watch(appDatabaseProvider)),
  );
});

final localDashboardOverlayProvider =
    FutureProvider.autoDispose<LocalDashboardOverlay>((ref) async {
  // Sum today's local sales that haven't been applied to backend yet.
  final db = await ref.watch(appDatabaseProvider).database;
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day)
      .millisecondsSinceEpoch;
  final startOfMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;

  // Join the queue for authoritative sync status where possible.
  final pendingSalesToday = await db.rawQuery(
    '''
SELECT s.total_amount AS total_amount
FROM sales_local s
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
WHERE s.sale_status != ?
  AND s.created_at >= ?
  AND COALESCE(q.status, s.status) IN (?, ?, ?)
''',
    [
      'voided',
      startOfDay,
      'pending',
      'failed',
      'sending',
    ],
  );

  int todaySalesMinor = 0;
  for (final row in pendingSalesToday) {
    final value = (row['total_amount'] ?? '0.00').toString();
    todaySalesMinor += _moneyToMinor(value);
  }

  final pendingExpensesToday = await db.rawQuery(
    '''
SELECT e.amount AS amount
FROM expenses_local e
LEFT JOIN sync_queue q
  ON q.local_operation_id = e.local_operation_id
 AND q.source_device_id = e.source_device_id
WHERE e.created_at >= ?
  AND COALESCE(q.status, e.status) IN (?, ?, ?)
''',
    [startOfDay, 'pending', 'failed', 'sending'],
  );
  int todayExpensesMinor = 0;
  for (final row in pendingExpensesToday) {
    final value = (row['amount'] ?? '0.00').toString();
    todayExpensesMinor += _moneyToMinor(value);
  }

  final pendingSalesMonth = await db.rawQuery(
    '''
SELECT s.total_amount AS total_amount, s.payment_method_label AS method
FROM sales_local s
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
WHERE s.sale_status != ?
  AND s.created_at >= ?
  AND COALESCE(q.status, s.status) IN (?, ?, ?)
''',
    ['voided', startOfMonth, 'pending', 'failed', 'sending'],
  );
  int monthSalesMinor = 0;
  final monthByMethod = <String, int>{};
  for (final row in pendingSalesMonth) {
    final value = (row['total_amount'] ?? '0.00').toString();
    final m = (row['method'] ?? 'cash').toString();
    final minor = _moneyToMinor(value);
    monthSalesMinor += minor;
    monthByMethod[m] = (monthByMethod[m] ?? 0) + minor;
  }

  final pendingExpensesMonth = await db.rawQuery(
    '''
SELECT e.amount AS amount
FROM expenses_local e
LEFT JOIN sync_queue q
  ON q.local_operation_id = e.local_operation_id
 AND q.source_device_id = e.source_device_id
WHERE e.created_at >= ?
  AND COALESCE(q.status, e.status) IN (?, ?, ?)
''',
    [startOfMonth, 'pending', 'failed', 'sending'],
  );
  int monthExpensesMinor = 0;
  for (final row in pendingExpensesMonth) {
    final value = (row['amount'] ?? '0.00').toString();
    monthExpensesMinor += _moneyToMinor(value);
  }

  final pendingTopSellingMonth = await db.rawQuery(
    '''
SELECT si.item_id AS item_id,
       COALESCE(i.name, 'Item') AS item_name,
       SUM(si.quantity) AS qty,
       SUM(CAST(si.line_total AS REAL)) AS total_real
FROM sale_items_local si
JOIN sales_local s ON s.id = si.sale_id
LEFT JOIN items_local i ON i.id = si.item_id
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
WHERE s.sale_status != ?
  AND s.created_at >= ?
  AND COALESCE(q.status, s.status) IN (?, ?, ?)
GROUP BY si.item_id, item_name
ORDER BY qty DESC, total_real DESC
LIMIT 3
''',
    ['voided', startOfMonth, 'pending', 'failed', 'sending'],
  );
  final topSelling = pendingTopSellingMonth.map((row) {
    final raw = (row['total_real'] as num? ?? 0.0).toDouble();
    final minor = (raw * 100).round();
    return LocalTopSellingOverlayRow(
      itemId: (row['item_id'] ?? '') as String,
      itemName: (row['item_name'] ?? 'Item') as String,
      quantitySold: (row['qty'] as int? ?? 0),
      salesTotalMinor: minor,
    );
  }).toList(growable: false);

  final lowStockRows = await db.rawQuery(
    '''
SELECT COUNT(*) AS total
FROM items_local
WHERE is_active = 1
  AND low_stock_threshold IS NOT NULL
  AND low_stock_threshold > 0
  AND quantity_on_hand <= low_stock_threshold
''',
  );
  final lowStockCount = lowStockRows.isEmpty
      ? 0
      : (lowStockRows.first['total'] as int? ?? 0);

  final debtRows = await db.rawQuery(
    '''
SELECT COALESCE(SUM(CAST(outstanding_amount AS REAL)), 0.0) AS total_real
FROM receivables_local
WHERE status IN ('open', 'partially_paid')
''',
  );
  final debtReal = (debtRows.isEmpty
          ? 0.0
          : (debtRows.first['total_real'] as num? ?? 0.0))
      .toDouble();
  final debtMinor = (debtReal * 100).round();

  return LocalDashboardOverlay(
    todayPendingSalesMinor: todaySalesMinor,
    todayPendingSalesCount: pendingSalesToday.length,
    todayPendingExpensesMinor: todayExpensesMinor,
    monthPendingSalesMinor: monthSalesMinor,
    monthPendingExpensesMinor: monthExpensesMinor,
    monthPendingPaymentMinorByMethod: monthByMethod,
    monthPendingTopSelling: topSelling,
    lowStockCountLocal: lowStockCount,
    debtOutstandingMinorLocal: debtMinor,
  );
});

final localPendingActivityProvider =
    FutureProvider.autoDispose<List<LocalPendingActivityRow>>((ref) async {
  final db = await ref.watch(appDatabaseProvider).database;

  final rows = await db.rawQuery(
    '''
SELECT 'sale' AS activity_type,
       s.id AS id,
       s.total_amount AS amount,
       s.created_at AS created_at
FROM sales_local s
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
WHERE s.sale_status != 'voided'
  AND COALESCE(q.status, s.status) IN ('pending', 'failed', 'sending')
UNION ALL
SELECT 'expense' AS activity_type,
       e.id AS id,
       e.amount AS amount,
       e.created_at AS created_at
FROM expenses_local e
LEFT JOIN sync_queue q
  ON q.local_operation_id = e.local_operation_id
 AND q.source_device_id = e.source_device_id
WHERE COALESCE(q.status, e.status) IN ('pending', 'failed', 'sending')
ORDER BY created_at DESC
LIMIT 6
''',
  );

  return rows.map((row) {
    final type = (row['activity_type'] ?? 'sale') as String;
    final amount = (row['amount'] ?? '0.00').toString();
    final createdAtMillis = (row['created_at'] as int? ?? 0);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtMillis);
    return LocalPendingActivityRow(
      activityType: type,
      title: type == 'expense' ? 'Expense (offline)' : 'Sale (offline)',
      detail: 'Pending sync',
      amount: amount,
      createdAt: createdAt,
    );
  }).toList(growable: false);
});

int _moneyToMinor(String value) {
  final raw = value.trim();
  final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
  if (match == null) return 0;
  final parts = raw.split('.');
  final major = int.tryParse(parts[0]) ?? 0;
  final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final minor = int.tryParse(decimal) ?? 0;
  return (major * 100) + minor;
}

String minorToMoney(int value) {
  final abs = value.abs();
  final major = abs ~/ 100;
  final minor = (abs % 100).toString().padLeft(2, '0');
  final sign = value < 0 ? '-' : '';
  return '$sign$major.$minor';
}

final merchantContextProvider =
    StreamProvider.autoDispose<MerchantContext>((ref) {
  return ref.watch(dashboardApiProvider).streamContext();
});

final dashboardSummaryProvider =
    StreamProvider.autoDispose<DashboardSummary>((ref) {
  return ref.watch(dashboardApiProvider).streamSummary();
});

final dashboardRecentActivityProvider =
    StreamProvider.autoDispose<List<DashboardActivity>>((ref) {
  return ref.watch(dashboardApiProvider).streamRecentActivity();
});

final dashboardInsightsProvider =
    StreamProvider.autoDispose<DashboardInsights>((ref) {
  return ref.watch(dashboardApiProvider).streamInsights();
});
