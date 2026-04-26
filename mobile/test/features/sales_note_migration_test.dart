import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:biztrack_gh/core/services/api_client.dart';
import 'package:biztrack_gh/core/services/secure_token_storage.dart';
import 'package:biztrack_gh/data/local/app_database.dart';
import 'package:biztrack_gh/data/local/sync_queue_repository.dart';
import 'package:biztrack_gh/data/remote/sync_api.dart';
import 'package:biztrack_gh/data/sync/sync_queue_runner.dart';
import 'package:biztrack_gh/features/sales/data/sales_repository.dart';

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
  Future<void> close() async => _db.close();
}

/// Opens an in-memory DB with the v6 sales schema (no note column).
Future<Database> _openV6Database() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
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
        // v6 schema — intentionally missing the note column.
        await db.execute('''
CREATE TABLE sales_local (
  id TEXT PRIMARY KEY NOT NULL,
  payment_method_label TEXT NOT NULL,
  total_amount TEXT NOT NULL,
  sale_status TEXT NOT NULL DEFAULT 'recorded',
  voided_at INTEGER,
  void_reason TEXT,
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

/// Opens an in-memory DB with the v7 sales schema (includes note column).
Future<Database> _openV7Database() async {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
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
        // v7 schema — note column present.
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

String _randomItemId() =>
    DateTime.now().microsecondsSinceEpoch.toString().padLeft(32, '0');

Future<String> _seedItem(Database db) async {
  final id = _randomItemId();
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert('items_local', {
    'id': id,
    'name': 'Test Item',
    'default_price': '10.00',
    'is_active': 1,
    'quantity_on_hand': 20,
    'created_at': now,
    'updated_at': now,
  });
  return id;
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
}

class _FakeSyncApi extends SyncApi {
  _FakeSyncApi()
      : super(ApiClient(tokenStorage: _FakeSecureTokenStorage(), dio: Dio()));

  @override
  Future<List<SyncApplyResult>> apply({
    required String deviceId,
    required List<SyncOperationPayload> operations,
  }) async =>
      const [];
}

SalesRepository _makeRepo(Database db) {
  final appDb = _InMemoryAppDatabase(db);
  return SalesRepository(
    appDb: appDb,
    syncQueueRunner: SyncQueueRunner(appDb: appDb, syncApi: _FakeSyncApi()),
  );
}

void main() {
  group('sales_note_migration', () {
    test('v7 upgrade adds note column to existing v6 table', () async {
      final db = await _openV6Database();
      try {
        // Simulate the _upgradeSalesSchemaV7 logic.
        final cols = await db.rawQuery('PRAGMA table_info(sales_local)');
        final names = cols.map((r) => (r['name'] ?? '').toString()).toSet();
        expect(names.contains('note'), isFalse,
            reason: 'v6 schema should not have note column yet');

        if (!names.contains('note')) {
          await db.execute('ALTER TABLE sales_local ADD COLUMN note TEXT');
        }

        final colsAfter = await db.rawQuery('PRAGMA table_info(sales_local)');
        final namesAfter =
            colsAfter.map((r) => (r['name'] ?? '').toString()).toSet();
        expect(namesAfter.contains('note'), isTrue);
      } finally {
        await db.close();
      }
    });

    test('createSaleLocal persists note field', () async {
      final db = await _openV7Database();
      try {
        final itemId = await _seedItem(db);
        final repo = _makeRepo(db);

        await repo.createSaleLocal(
          paymentMethodLabel: 'cash',
          lines: [
            SaleDraftLine(itemId: itemId, quantity: 1, unitPrice: '10.00')
          ],
          note: 'Please bring change',
        );

        final rows = await db.query('sales_local', limit: 1);
        expect(rows, hasLength(1));
        expect(rows.first['note'], equals('Please bring change'));
      } finally {
        await db.close();
      }
    });

    test('note appears in sync queue payload JSON', () async {
      final db = await _openV7Database();
      try {
        final itemId = await _seedItem(db);
        final repo = _makeRepo(db);
        const noteText = 'Wholesale customer';

        await repo.createSaleLocal(
          paymentMethodLabel: 'cash',
          lines: [
            SaleDraftLine(itemId: itemId, quantity: 2, unitPrice: '10.00')
          ],
          note: noteText,
        );

        final rows = await db.query(
          'sync_queue',
          where: "entity_type = 'sale' AND operation = 'create'",
          limit: 1,
        );
        expect(rows, hasLength(1));
        final payload = jsonDecode(rows.first['payload_json'] as String)
            as Map<String, dynamic>;
        expect(payload['note'], equals(noteText));
      } finally {
        await db.close();
      }
    });

    test('createSaleLocal with null note omits note from payload', () async {
      final db = await _openV7Database();
      try {
        final itemId = await _seedItem(db);
        final repo = _makeRepo(db);

        await repo.createSaleLocal(
          paymentMethodLabel: 'cash',
          lines: [
            SaleDraftLine(itemId: itemId, quantity: 1, unitPrice: '10.00')
          ],
          // note omitted
        );

        final rows = await db.query(
          'sync_queue',
          where: "entity_type = 'sale' AND operation = 'create'",
          limit: 1,
        );
        final payload = jsonDecode(rows.first['payload_json'] as String)
            as Map<String, dynamic>;
        expect(payload.containsKey('note'), isFalse);
      } finally {
        await db.close();
      }
    });
  });
}
