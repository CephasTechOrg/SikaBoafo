import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/sync/sync_queue_runner.dart';

class LocalExpenseRecord {
  const LocalExpenseRecord({
    required this.expenseId,
    required this.category,
    required this.amount,
    required this.syncStatus,
    required this.createdAtMillis,
    this.note,
  });

  final String expenseId;
  final String category;
  final String amount;
  final String? note;
  final String syncStatus;
  final int createdAtMillis;

  factory LocalExpenseRecord.fromRow(Map<String, Object?> row) {
    return LocalExpenseRecord(
      expenseId: (row['id'] ?? '') as String,
      category: (row['category'] ?? 'other') as String,
      amount: (row['amount'] ?? '0.00') as String,
      note: row['note'] as String?,
      syncStatus: (row['sync_status'] ?? 'pending') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}

class ExpensesRepository {
  ExpensesRepository({
    required AppDatabase appDb,
    required SyncQueueRunner syncQueueRunner,
  })  : _appDb = appDb,
        _syncQueueRunner = syncQueueRunner;

  final AppDatabase _appDb;
  final SyncQueueRunner _syncQueueRunner;
  final _uuid = const Uuid();

  static const allowedCategories = <String>{
    'inventory_purchase',
    'transport',
    'utilities',
    'rent',
    'salary',
    'tax',
    'other',
  };

  Future<List<LocalExpenseRecord>> listRecentExpenses({int limit = 40}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT e.id, e.category, e.amount, e.note, e.created_at,
       COALESCE(q.status, e.status) AS sync_status
FROM expenses_local e
LEFT JOIN sync_queue q
  ON q.local_operation_id = e.local_operation_id
 AND q.source_device_id = e.source_device_id
ORDER BY e.created_at DESC
LIMIT ?
''',
      [limit],
    );
    return rows.map(LocalExpenseRecord.fromRow).toList(growable: false);
  }

  Future<void> createExpenseLocal({
    required String category,
    required String amount,
    String? note,
  }) async {
    final normalizedCategory = category.trim().toLowerCase();
    if (!allowedCategories.contains(normalizedCategory)) {
      throw ArgumentError('Unsupported expense category: $category');
    }
    final amountMinor = _moneyToMinor(amount);
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than 0.');
    }

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final expenseId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedAmount = _minorToMoney(amountMinor);
    final cleanedNote = _cleanOptional(note);

    await db.transaction((tx) async {
      await tx.insert(
        'expenses_local',
        {
          'id': expenseId,
          'category': normalizedCategory,
          'amount': normalizedAmount,
          'note': cleanedNote,
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'status': 'pending',
          'created_at': now,
        },
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'expense',
        operation: 'create',
        entityId: expenseId,
        payloadJson: jsonEncode(
          {
            'expense_id': expenseId,
            'category': normalizedCategory,
            'amount': normalizedAmount,
            'note': cleanedNote,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<SyncQueueRunSummary> syncPendingQueue({int limit = 100}) {
    return _syncQueueRunner.run(limit: limit);
  }

  int _moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) {
      throw ArgumentError('Invalid amount: $value');
    }
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(decimal);
  }

  String _minorToMoney(int value) {
    final major = value ~/ 100;
    final minor = (value % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }

  String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
