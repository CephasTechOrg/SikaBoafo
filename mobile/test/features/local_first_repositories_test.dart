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
import 'package:biztrack_gh/features/debts/data/debts_repository.dart';
import 'package:biztrack_gh/features/expenses/data/expenses_repository.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_api.dart';
import 'package:biztrack_gh/features/inventory/data/inventory_repository.dart';
import 'package:biztrack_gh/features/sales/data/sales_repository.dart';

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
  }) async {
    return const [];
  }
}

class _FakeInventoryApi extends InventoryApi {
  _FakeInventoryApi()
      : super(ApiClient(tokenStorage: _FakeSecureTokenStorage(), dio: Dio()));

  @override
  Future<List<InventoryItemDto>> fetchItems() async =>
      const <InventoryItemDto>[];
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

Future<Database> _openInMemoryDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
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
  image_asset TEXT,
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

        await db.execute('''
CREATE TABLE expenses_local (
  id TEXT PRIMARY KEY NOT NULL,
  category TEXT NOT NULL,
  amount TEXT NOT NULL,
  note TEXT,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL
)
''');

        await db.execute('''
CREATE TABLE customers_local (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  phone_number TEXT,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

        await db.execute('''
CREATE TABLE receivables_local (
  id TEXT PRIMARY KEY NOT NULL,
  customer_id TEXT NOT NULL,
  original_amount TEXT NOT NULL,
  outstanding_amount TEXT NOT NULL,
  due_date TEXT,
  status TEXT NOT NULL,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)
''');

        await db.execute('''
CREATE TABLE receivable_payments_local (
  id TEXT PRIMARY KEY NOT NULL,
  receivable_id TEXT NOT NULL,
  amount TEXT NOT NULL,
  payment_method_label TEXT NOT NULL,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL
)
''');
      },
    ),
  );
  return db;
}

SyncQueueRunner _unusedRunner(AppDatabase appDb) {
  return SyncQueueRunner(appDb: appDb, syncApi: _FakeSyncApi());
}

void main() {
  test(
      'inventory create with initial stock writes quantity and enqueues item+stock_in',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = InventoryRepository(
      appDb: appDb,
      inventoryApi: _FakeInventoryApi(),
      syncQueueRunner: _unusedRunner(appDb),
    );

    await repo.createItemLocal(
      name: 'Oil',
      defaultPrice: '12.00',
      category: 'groceries',
      lowStockThreshold: 3,
      initialQuantity: 7,
    );

    final itemRows = await db.query('items_local');
    final movementRows = await db.query('inventory_movements_local');
    final queueRows = await db.query('sync_queue', orderBy: 'id ASC');

    expect(itemRows, hasLength(1));
    expect(itemRows.first['quantity_on_hand'], 7);

    expect(movementRows, hasLength(1));
    expect(movementRows.first['movement_type'], 'stock_in');
    expect(movementRows.first['quantity'], 7);

    expect(queueRows, hasLength(2));
    expect(queueRows[0]['entity_type'], 'item');
    expect(queueRows[0]['operation'], 'create');
    expect(queueRows[1]['entity_type'], 'inventory');
    expect(queueRows[1]['operation'], 'stock_in');

    final stockPayload = jsonDecode(queueRows[1]['payload_json'] as String)
        as Map<String, dynamic>;
    expect(stockPayload['quantity'], 7);

    await appDb.close();
  });

  test('inventory archive flips is_active and enqueues item update', () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = InventoryRepository(
      appDb: appDb,
      inventoryApi: _FakeInventoryApi(),
      syncQueueRunner: _unusedRunner(appDb),
    );

    await db.insert('items_local', {
      'id': 'item-1',
      'name': 'Soap',
      'default_price': '4.50',
      'sku': 'SOAP-1',
      'category': 'groceries',
      'low_stock_threshold': 2,
      'is_active': 1,
      'quantity_on_hand': 0,
      'created_at': 1,
      'updated_at': 1,
    });

    await repo.archiveItemLocal(itemId: 'item-1');

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final queueRows = await db.query('sync_queue');

    expect(itemRows.first['is_active'], 0);
    expect(queueRows, hasLength(1));
    expect(queueRows.first['entity_type'], 'item');
    expect(queueRows.first['operation'], 'update');

    final payload = jsonDecode(queueRows.first['payload_json'] as String)
        as Map<String, dynamic>;
    expect(payload['item_id'], 'item-1');
    expect(payload['is_active'], isFalse);

    await appDb.close();
  });

  test('inventory restore flips is_active back to true and enqueues item update',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = InventoryRepository(
      appDb: appDb,
      inventoryApi: _FakeInventoryApi(),
      syncQueueRunner: _unusedRunner(appDb),
    );

    await db.insert('items_local', {
      'id': 'item-1',
      'name': 'Soap',
      'default_price': '4.50',
      'sku': 'SOAP-1',
      'category': 'groceries',
      'low_stock_threshold': 2,
      'is_active': 0,
      'quantity_on_hand': 0,
      'created_at': 1,
      'updated_at': 1,
    });

    await repo.restoreItemLocal(itemId: 'item-1');

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final queueRows = await db.query('sync_queue');

    expect(itemRows.first['is_active'], 1);
    expect(queueRows, hasLength(1));
    expect(queueRows.first['entity_type'], 'item');
    expect(queueRows.first['operation'], 'update');

    final payload = jsonDecode(queueRows.first['payload_json'] as String)
        as Map<String, dynamic>;
    expect(payload['item_id'], 'item-1');
    expect(payload['is_active'], isTrue);

    await appDb.close();
  });

  test('inventory archive is rejected while stock remains', () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = InventoryRepository(
      appDb: appDb,
      inventoryApi: _FakeInventoryApi(),
      syncQueueRunner: _unusedRunner(appDb),
    );

    await db.insert('items_local', {
      'id': 'item-1',
      'name': 'Soap',
      'default_price': '4.50',
      'sku': 'SOAP-1',
      'category': 'groceries',
      'low_stock_threshold': 2,
      'is_active': 1,
      'quantity_on_hand': 3,
      'created_at': 1,
      'updated_at': 1,
    });

    await expectLater(
      repo.archiveItemLocal(itemId: 'item-1'),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.message,
          'message',
          archiveRequiresZeroStockMessage,
        ),
      ),
    );

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final queueRows = await db.query('sync_queue');

    expect(itemRows.first['is_active'], 1);
    expect(queueRows, isEmpty);

    await appDb.close();
  });

  test(
      'expenses local-first write persists expense and enqueues sync operation',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = ExpensesRepository(
      appDb: appDb,
      syncQueueRunner: _unusedRunner(appDb),
    );

    await repo.createExpenseLocal(
      category: 'transport',
      amount: '12.50',
      note: 'Taxi to market',
    );

    final expenseRows = await db.query('expenses_local');
    final queueRows = await db.query('sync_queue');

    expect(expenseRows, hasLength(1));
    expect(queueRows, hasLength(1));

    final expense = expenseRows.first;
    final queue = queueRows.first;
    final payload =
        jsonDecode(queue['payload_json'] as String) as Map<String, dynamic>;

    expect(expense['category'], 'transport');
    expect(expense['amount'], '12.50');
    expect(expense['status'], 'pending');
    expect(expense['source_device_id'], 'test-device');
    expect(queue['entity_type'], 'expense');
    expect(queue['operation'], 'create');
    expect(queue['status'], SyncQueueRepository.pending);
    expect(payload['category'], 'transport');
    expect(payload['amount'], '12.50');

    await appDb.close();
  });

  test(
      'sales local-first write updates stock, writes sale rows, and enqueues sync',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = SalesRepository(
      appDb: appDb,
      syncQueueRunner: _unusedRunner(appDb),
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

    await repo.createSaleLocal(
      paymentMethodLabel: 'cash',
      lines: const [
        SaleDraftLine(itemId: 'item-1', quantity: 2, unitPrice: '3.00'),
      ],
    );

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final saleRows = await db.query('sales_local');
    final saleItemRows = await db.query('sale_items_local');
    final movementRows = await db.query('inventory_movements_local');
    final queueRows = await db.query('sync_queue');

    expect(itemRows.first['quantity_on_hand'], 8);
    expect(saleRows, hasLength(1));
    expect(saleItemRows, hasLength(1));
    expect(movementRows, hasLength(1));
    expect(queueRows, hasLength(1));

    final sale = saleRows.first;
    final queue = queueRows.first;
    final payload =
        jsonDecode(queue['payload_json'] as String) as Map<String, dynamic>;

    expect(sale['total_amount'], '6.00');
    expect(sale['payment_method_label'], 'cash');
    expect(queue['entity_type'], 'sale');
    expect(queue['operation'], 'create');
    expect(queue['status'], SyncQueueRepository.pending);

    final lines = (payload['lines'] as List<dynamic>);
    expect(lines, hasLength(1));
    expect((lines.first as Map<String, dynamic>)['item_id'], 'item-1');

    await appDb.close();
  });

  test(
      'sales local-first update adjusts stock/total and enqueues update operation',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = SalesRepository(
      appDb: appDb,
      syncQueueRunner: _unusedRunner(appDb),
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

    await repo.createSaleLocal(
      paymentMethodLabel: 'cash',
      lines: const [
        SaleDraftLine(itemId: 'item-1', quantity: 2, unitPrice: '3.00'),
      ],
    );

    final createdSaleRows = await db.query('sales_local');
    final saleId = createdSaleRows.first['id'] as String;
    await repo.updateSaleLocal(
      saleId: saleId,
      paymentMethodLabel: 'mobile_money',
      lines: const [
        SaleQuantityUpdateDraft(itemId: 'item-1', quantity: 4),
      ],
    );

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final saleRows = await db.query('sales_local');
    final saleItemRows = await db.query('sale_items_local');
    final queueRows = await db.query('sync_queue', orderBy: 'id ASC');

    expect(itemRows.first['quantity_on_hand'], 6);
    expect(saleRows.first['payment_method_label'], 'mobile_money');
    expect(saleRows.first['total_amount'], '12.00');
    expect(saleRows.first['sale_status'], 'recorded');
    expect(saleItemRows.first['quantity'], 4);

    expect(queueRows, hasLength(2));
    expect(queueRows[1]['entity_type'], 'sale');
    expect(queueRows[1]['operation'], 'update');
    final payload = jsonDecode(queueRows[1]['payload_json'] as String)
        as Map<String, dynamic>;
    expect(payload['sale_id'], saleId);
    expect(payload['payment_method_label'], 'mobile_money');

    await appDb.close();
  });

  test('sales local-first void restores stock and enqueues void operation',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = SalesRepository(
      appDb: appDb,
      syncQueueRunner: _unusedRunner(appDb),
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

    await repo.createSaleLocal(
      paymentMethodLabel: 'cash',
      lines: const [
        SaleDraftLine(itemId: 'item-1', quantity: 3, unitPrice: '3.00'),
      ],
    );
    final createdSaleRows = await db.query('sales_local');
    final saleId = createdSaleRows.first['id'] as String;

    await repo.voidSaleLocal(saleId: saleId, reason: 'customer returned');

    final itemRows =
        await db.query('items_local', where: 'id = ?', whereArgs: ['item-1']);
    final saleRows = await db.query('sales_local');
    final queueRows = await db.query('sync_queue', orderBy: 'id ASC');

    expect(itemRows.first['quantity_on_hand'], 10);
    expect(saleRows.first['sale_status'], 'voided');
    expect(saleRows.first['void_reason'], 'customer returned');
    expect(saleRows.first['voided_at'], isNotNull);

    expect(queueRows, hasLength(2));
    expect(queueRows[1]['entity_type'], 'sale');
    expect(queueRows[1]['operation'], 'void');
    final payload = jsonDecode(queueRows[1]['payload_json'] as String)
        as Map<String, dynamic>;
    expect(payload['sale_id'], saleId);
    expect(payload['reason'], 'customer returned');

    await appDb.close();
  });

  test(
      'debts local-first flow writes customer/receivable/repayment and queues all',
      () async {
    final db = await _openInMemoryDatabase();
    final appDb = _InMemoryAppDatabase(db);
    final repo = DebtsRepository(
      appDb: appDb,
      syncQueueRunner: _unusedRunner(appDb),
    );

    await repo.createCustomerLocal(
        name: 'Ama Mensah', phoneNumber: '0240000000');
    final customerRows = await db.query('customers_local');
    expect(customerRows, hasLength(1));
    final customerId = customerRows.first['id'] as String;

    await repo.createReceivableLocal(
      customerId: customerId,
      originalAmount: '50.00',
      dueDateIso: '2026-04-30',
    );

    final receivableRows = await db.query('receivables_local');
    expect(receivableRows, hasLength(1));
    final receivableId = receivableRows.first['id'] as String;

    await repo.recordRepaymentLocal(
      receivableId: receivableId,
      amount: '20.00',
      paymentMethodLabel: 'cash',
    );

    final updatedReceivableRows = await db
        .query('receivables_local', where: 'id = ?', whereArgs: [receivableId]);
    final paymentRows = await db.query('receivable_payments_local');
    final queueRows = await db.query('sync_queue', orderBy: 'id ASC');

    expect(updatedReceivableRows.first['outstanding_amount'], '30.00');
    expect(updatedReceivableRows.first['status'], 'open');
    expect(paymentRows, hasLength(1));
    expect(paymentRows.first['amount'], '20.00');

    expect(queueRows, hasLength(3));
    expect(queueRows[0]['entity_type'], 'customer');
    expect(queueRows[1]['entity_type'], 'receivable');
    expect(queueRows[2]['entity_type'], 'receivable_payment');
    expect(queueRows[0]['status'], SyncQueueRepository.pending);
    expect(queueRows[1]['status'], SyncQueueRepository.pending);
    expect(queueRows[2]['status'], SyncQueueRepository.pending);

    await appDb.close();
  });
}
