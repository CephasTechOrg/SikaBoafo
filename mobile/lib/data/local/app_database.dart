import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'sync_queue_repository.dart';

const _dbName = 'biztrack_gh.db';
const _schemaVersion = 1;

/// Local SQLite (offline-first). Sync queue aligns with server idempotency:
/// `source_device_id` + `local_operation_id` unique per logical write.
class AppDatabase {
  AppDatabase();

  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE local_meta (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  operation TEXT NOT NULL,
  entity_id TEXT,
  payload_json TEXT NOT NULL,
  source_device_id TEXT NOT NULL,
  local_operation_id TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  UNIQUE (source_device_id, local_operation_id)
)
''');
    await db.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue (status)',
    );
  }

  SyncQueueRepository get syncQueue => SyncQueueRepository(this);

  /// Stable device id for idempotent sync (stored in [local_meta]).
  Future<String> getOrCreateDeviceId() async {
    const key = 'device_id';
    final db = await database;
    final rows = await db.query('local_meta', where: 'key = ?', whereArgs: [key]);
    if (rows.isNotEmpty) {
      return rows.first['value']! as String;
    }
    final id = _uuid.v4();
    await db.insert('local_meta', {'key': key, 'value': id});
    return id;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
