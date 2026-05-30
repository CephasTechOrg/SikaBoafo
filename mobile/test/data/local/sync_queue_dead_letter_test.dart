import 'package:biztrack_gh/data/local/app_database.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryAppDatabase extends AppDatabase {
  _InMemoryAppDatabase(this._db);

  final Database _db;

  @override
  Future<Database> get database async => _db;

  @override
  SyncQueueRepository get syncQueue => SyncQueueRepository(this);
}

Future<Database> _openDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: 1,
      onCreate: (db, version) async {
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
      },
    ),
  );
}

void main() {
  late Database db;
  late SyncQueueRepository repo;

  setUp(() async {
    db = await _openDb();
    repo = _InMemoryAppDatabase(db).syncQueue;
    final id = await repo.enqueue(
      entityType: 'receivable',
      operation: 'create',
      payloadJson: '{"amount":"10.00"}',
      sourceDeviceId: 'device-1',
      localOperationId: 'op-dead-1',
    );
    await repo.markDead(id, 'Exceeded retry attempts.');
  });

  tearDown(() async {
    await db.close();
  });

  test('deadRows returns stopped entries', () async {
    final rows = await repo.deadRows();
    expect(rows, hasLength(1));
    expect(rows.first.status, SyncQueueRepository.dead);
    expect(rows.first.lastError, contains('Exceeded'));
  });

  test('reviveFromDead requeues a single row', () async {
    await repo.reviveFromDead(1);
    final stats = await repo.stats();
    expect(stats.deadCount, 0);
    expect(stats.pendingCount, 1);
  });

  test('reviveAllDead requeues every stopped row', () async {
    final id2 = await repo.enqueue(
      entityType: 'sale',
      operation: 'create',
      payloadJson: '{}',
      sourceDeviceId: 'device-1',
      localOperationId: 'op-dead-2',
    );
    await repo.markDead(id2, 'Manually discarded by user.');
    await repo.reviveAllDead();
    final stats = await repo.stats();
    expect(stats.deadCount, 0);
    expect(stats.pendingCount, 2);
  });

  test('deleteDead permanently removes a stopped row', () async {
    await repo.deleteDead(1);
    final rows = await repo.deadRows();
    expect(rows, isEmpty);
    final stats = await repo.stats();
    expect(stats.deadCount, 0);
  });
}
