import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Pending outbound operations for `/api/v1/sync` (see backend `sync_operations`).
class SyncQueueRepository {
  SyncQueueRepository(this._appDb);

  final AppDatabase _appDb;

  static const pending = 'pending';
  static const sending = 'sending';
  static const failed = 'failed';
  static const applied = 'applied';

  Future<int> enqueue({
    required String entityType,
    required String operation,
    String? entityId,
    required String payloadJson,
    required String sourceDeviceId,
    required String localOperationId,
  }) async {
    final db = await _appDb.database;
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

  Future<List<Map<String, Object?>>> pendingRows({int limit = 100}) async {
    final db = await _appDb.database;
    return db.query(
      'sync_queue',
      where: 'status IN (?, ?)',
      whereArgs: [pending, failed],
      orderBy: 'created_at ASC',
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
      {'status': applied},
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
}
