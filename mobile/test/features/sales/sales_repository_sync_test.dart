import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/data/local/app_database.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:biztrack_gh/data/remote/sync_api.dart';
import 'package:biztrack_gh/data/sync/sync_queue_runner.dart';
import 'package:biztrack_gh/features/sales/data/sales_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class _NoopSyncQueueRunner extends SyncQueueRunner {
  _NoopSyncQueueRunner({required AppDatabase appDb})
      : super(appDb: appDb, syncApi: _EmptyApplySyncApi());

  @override
  Future<SyncQueueRunSummary> run({int limit = 100}) async {
    return const SyncQueueRunSummary(
      applied: 0,
      failed: 0,
      conflicts: 0,
      statusByOperationId: {},
    );
  }
}

class _EmptyApplySyncApi extends SyncApi {
  _EmptyApplySyncApi()
      : super(ApiClient(tokenStorage: _FakeSecureTokenStorage(), dio: Dio()));

  @override
  Future<List<SyncApplyResult>> apply({
    required String deviceId,
    required List<SyncOperationPayload> operations,
  }) async =>
      const [];
}

class _InMemoryAppDatabase extends AppDatabase {
  _InMemoryAppDatabase(this._db);

  final Database _db;

  @override
  Future<Database> get database async => _db;

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  SyncQueueRepository get syncQueue => SyncQueueRepository(this);

  @override
  Future<void> close() async {
    await _db.close();
  }
}

Future<Database> _openDb() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: 1,
      onCreate: (db, _) async {
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
        await db.execute('''
CREATE TABLE items_local (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  default_price TEXT NOT NULL,
  sku TEXT,
  category TEXT,
  low_stock_threshold INTEGER,
  is_active INTEGER NOT NULL DEFAULT 1,
  quantity_on_hand INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE inventory_movements_local (
  id TEXT PRIMARY KEY NOT NULL,
  item_id TEXT NOT NULL,
  movement_type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  reason TEXT,
  local_operation_id TEXT,
  created_at INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE sales_local (
  id TEXT PRIMARY KEY NOT NULL,
  payment_method_label TEXT NOT NULL,
  total_amount TEXT NOT NULL,
  sale_status TEXT NOT NULL DEFAULT 'recorded',
  voided_at INTEGER,
  void_reason TEXT,
  note TEXT,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL
)
''');
        await db.execute('''
CREATE TABLE sale_items_local (
  id TEXT PRIMARY KEY NOT NULL,
  sale_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price TEXT NOT NULL,
  line_total TEXT NOT NULL,
  created_at INTEGER NOT NULL
)
''');
      },
    ),
  );
}

void main() {
  test('hasUnresolvedItemCreatesForIds detects pending item create rows', () async {
    final db = await _openDb();
    final appDb = _InMemoryAppDatabase(db);
    final repo = appDb.syncQueue;

    await repo.enqueue(
      entityType: 'item',
      operation: 'create',
      entityId: 'item-1',
      payloadJson: '{"item_id":"item-1","name":"Bread"}',
      sourceDeviceId: 'test-device',
      localOperationId: 'item-op-1',
    );

    expect(await repo.hasUnresolvedItemCreatesForIds(['item-1']), isTrue);
    expect(await repo.hasUnresolvedItemCreatesForIds(['item-2']), isFalse);

    await appDb.close();
  });

  test(
      'ensureSaleCreateSyncedToBackend fails fast when sale create is failed',
      () async {
    final db = await _openDb();
    final appDb = _InMemoryAppDatabase(db);
    final salesRepo = SalesRepository(
      appDb: appDb,
      syncQueueRunner: _NoopSyncQueueRunner(appDb: appDb),
    );

    await db.insert('items_local', {
      'id': 'item-1',
      'name': 'Bread',
      'default_price': '3.00',
      'sku': null,
      'category': 'food',
      'low_stock_threshold': 2,
      'is_active': 1,
      'quantity_on_hand': 10,
      'created_at': 1,
      'updated_at': 1,
    });

    final saleId = await salesRepo.createSaleLocal(
      paymentMethodLabel: 'mobile_money',
      lines: const [
        SaleDraftLine(itemId: 'item-1', quantity: 1, unitPrice: '3.00'),
      ],
    );

    final queueRow = await appDb.syncQueue.rowForSaleCreate(saleId);
    expect(queueRow, isNotNull);
    await appDb.syncQueue.markFailed(
      queueRow!['id'] as int,
      'Item not found for store: item-1',
    );

    final started = DateTime.now();
    await expectLater(
      salesRepo.ensureSaleCreateSyncedToBackend(
        saleId,
        budget: const Duration(seconds: 5),
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Item not found for store: item-1',
        ),
      ),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 3)),
    );

    await appDb.close();
  });
}
