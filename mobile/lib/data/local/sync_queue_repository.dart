import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class SyncQueueStats {
  const SyncQueueStats({
    required this.pendingCount,
    required this.sendingCount,
    required this.failedCount,
    required this.conflictCount,
    required this.appliedCount,
    this.deadCount = 0,
  });

  final int pendingCount;
  final int sendingCount;
  final int failedCount;
  final int conflictCount;
  final int appliedCount;
  final int deadCount;

  int get actionableCount => pendingCount + failedCount;
  int get issueCount => failedCount + conflictCount;
}

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.status,
    required this.createdAtMillis,
    required this.attempts,
    this.entityId,
    this.lastError,
  });

  final int id;
  final String entityType;
  final String operation;
  final String status;
  final int createdAtMillis;
  final int attempts;
  final String? entityId;
  final String? lastError;

  factory SyncQueueEntry.fromRow(Map<String, Object?> row) {
    return SyncQueueEntry(
      id: (row['id'] as int? ?? 0),
      entityType: (row['entity_type'] ?? '') as String,
      operation: (row['operation'] ?? '') as String,
      status: (row['status'] ?? '') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
      attempts: (row['attempts'] as int? ?? 0),
      entityId: row['entity_id'] as String?,
      lastError: row['last_error'] as String?,
    );
  }
}

/// Pending outbound operations for `/api/v1/sync` (see backend `sync_operations`).
class SyncQueueRepository {
  SyncQueueRepository(this._appDb);

  final AppDatabase _appDb;

  static const pending = 'pending';
  static const sending = 'sending';
  static const failed = 'failed';
  static const conflict = 'conflict';
  static const applied = 'applied';
  static const dead = 'dead';

  static const maxAttempts = 10;

  Future<int> enqueue({
    required String entityType,
    required String operation,
    String? entityId,
    required String payloadJson,
    required String sourceDeviceId,
    required String localOperationId,
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert(
      'sync_queue',
      {
        'entity_type': entityType,
        'operation': operation,
        'entity_id': entityId,
        'payload_json': payloadJson,
        'source_device_id': sourceDeviceId,
        'local_operation_id': localOperationId,
        'status': pending,
        'created_at': now,
        'attempts': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Latest queue row for an outbound sale create (used to verify server sync).
  Future<Map<String, Object?>?> rowForSaleCreate(String saleId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'sync_queue',
      where: 'entity_id = ? AND entity_type = ? AND operation = ?',
      whereArgs: [saleId, 'sale', 'create'],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> pendingRows({int limit = 100}) async {
    final db = await _appDb.database;
    return db.query(
      'sync_queue',
      where: 'status IN (?, ?, ?)',
      whereArgs: [pending, failed, sending],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
  }

  Future<void> markSending(int id) async {
    final db = await _appDb.database;
    await db.update(
      'sync_queue',
      {'status': sending},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markApplied(int id) async {
    final db = await _appDb.database;
    await db.update(
      'sync_queue',
      {'status': applied, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, String message) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      '''
UPDATE sync_queue
SET status = ?, attempts = attempts + 1, last_error = ?
WHERE id = ?
''',
      [failed, message, id],
    );
  }

  Future<void> markConflict(int id, String message) async {
    final db = await _appDb.database;
    await db.rawUpdate(
      '''
UPDATE sync_queue
SET status = ?, attempts = attempts + 1, last_error = ?
WHERE id = ?
''',
      [conflict, message, id],
    );
  }

  Future<void> markDead(int id, String reason) async {
    final db = await _appDb.database;
    await db.update(
      'sync_queue',
      {'status': dead, 'last_error': reason},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reviveFromDead(int id) async {
    final db = await _appDb.database;
    await db.update(
      'sync_queue',
      {'status': pending, 'last_error': null},
      where: 'id = ? AND status = ?',
      whereArgs: [id, dead],
    );
  }

  Future<SyncQueueStats> stats() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
SELECT status, COUNT(*) AS total
FROM sync_queue
GROUP BY status
''');
    int pendingCount = 0;
    int sendingCount = 0;
    int failedCount = 0;
    int conflictCount = 0;
    int appliedCount = 0;
    int deadCount = 0;
    for (final row in rows) {
      final status = (row['status'] ?? '') as String;
      final total = (row['total'] as int? ?? 0);
      switch (status) {
        case pending:
          pendingCount = total;
          break;
        case sending:
          sendingCount = total;
          break;
        case failed:
          failedCount = total;
          break;
        case conflict:
          conflictCount = total;
          break;
        case applied:
          appliedCount = total;
          break;
        case dead:
          deadCount = total;
          break;
      }
    }
    return SyncQueueStats(
      pendingCount: pendingCount,
      sendingCount: sendingCount,
      failedCount: failedCount,
      conflictCount: conflictCount,
      appliedCount: appliedCount,
      deadCount: deadCount,
    );
  }

  Future<List<SyncQueueEntry>> failedRows({int limit = 10}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: [failed, conflict],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromRow).toList(growable: false);
  }

  Future<List<SyncQueueEntry>> deadRows({int limit = 20}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'sync_queue',
      where: 'status = ?',
      whereArgs: [dead],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(SyncQueueEntry.fromRow).toList(growable: false);
  }

  Future<void> requeueFailed({int? id}) async {
    final db = await _appDb.database;
    if (id == null) {
      await db.update(
        'sync_queue',
        {'status': pending, 'last_error': null},
        where: 'status = ?',
        whereArgs: [failed],
      );
      return;
    }
    await db.update(
      'sync_queue',
      {'status': pending, 'last_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes [applied] rows older than [maxAgeDays] days. Never touches
  /// failed, conflict, or dead rows.
  Future<int> pruneOldApplied({int maxAgeDays = 30}) async {
    final db = await _appDb.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: maxAgeDays))
        .millisecondsSinceEpoch;
    return db.delete(
      'sync_queue',
      where: 'status = ? AND created_at < ?',
      whereArgs: [applied, cutoff],
    );
  }
}
