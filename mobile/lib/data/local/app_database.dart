import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'sync_queue_repository.dart';

const _dbName = 'biztrack_gh.db';
const _schemaVersion = 9;

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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createInventorySchema(db);
        }
        if (oldVersion < 3) {
          await _createSalesSchema(db);
        }
        if (oldVersion < 4) {
          await _createExpenseSchema(db);
        }
        if (oldVersion < 5) {
          await _createDebtSchema(db);
        }
        if (oldVersion < 6) {
          await _upgradeSalesSchemaV6(db);
        }
        if (oldVersion < 7) {
          await _upgradeSalesSchemaV7(db);
        }
        if (oldVersion < 8) {
          await _upgradeDebtsSchemaV8(db);
        }
        if (oldVersion < 9) {
          await _upgradeInventorySchemaV9(db);
        }
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
    await _createInventorySchema(db);
    await _createSalesSchema(db);
    await _createExpenseSchema(db);
    await _createDebtSchema(db);
  }

  Future<void> _createInventorySchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS items_local (
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
CREATE TABLE IF NOT EXISTS inventory_movements_local (
  id TEXT PRIMARY KEY NOT NULL,
  item_id TEXT NOT NULL,
  movement_type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  reason TEXT,
  local_operation_id TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items_local(id) ON DELETE CASCADE
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_items_local_name ON items_local (name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inventory_movements_item '
      'ON inventory_movements_local (item_id, created_at DESC)',
    );
  }

  Future<void> _createSalesSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS sales_local (
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
CREATE TABLE IF NOT EXISTS sale_items_local (
  id TEXT PRIMARY KEY NOT NULL,
  sale_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price TEXT NOT NULL,
  line_total TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY (sale_id) REFERENCES sales_local(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES items_local(id) ON DELETE RESTRICT
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_local_created_at '
      'ON sales_local (created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_local_status '
      'ON sales_local (sale_status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_local_sale '
      'ON sale_items_local (sale_id)',
    );
  }

  Future<void> _upgradeSalesSchemaV7(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(sales_local)');
    final names = cols.map((r) => (r['name'] ?? '').toString()).toSet();
    if (!names.contains('note')) {
      await db.execute('ALTER TABLE sales_local ADD COLUMN note TEXT');
    }
  }

  Future<void> _upgradeDebtsSchemaV8(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(receivables_local)');
    final names = cols.map((r) => (r['name'] ?? '').toString()).toSet();
    if (!names.contains('note')) {
      await db.execute('ALTER TABLE receivables_local ADD COLUMN note TEXT');
    }
  }

  Future<void> _upgradeInventorySchemaV9(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(items_local)');
    final names = cols.map((r) => (r['name'] ?? '').toString()).toSet();
    if (!names.contains('image_asset')) {
      await db.execute('ALTER TABLE items_local ADD COLUMN image_asset TEXT');
    }
  }

  Future<void> _upgradeSalesSchemaV6(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(sales_local)');
    final names = columns
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!names.contains('sale_status')) {
      await db.execute(
        "ALTER TABLE sales_local "
        "ADD COLUMN sale_status TEXT NOT NULL DEFAULT 'recorded'",
      );
    }
    if (!names.contains('voided_at')) {
      await db.execute('ALTER TABLE sales_local ADD COLUMN voided_at INTEGER');
    }
    if (!names.contains('void_reason')) {
      await db.execute('ALTER TABLE sales_local ADD COLUMN void_reason TEXT');
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_local_status '
      'ON sales_local (sale_status)',
    );
  }

  Future<void> _createExpenseSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS expenses_local (
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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_local_created_at '
      'ON expenses_local (created_at DESC)',
    );
  }

  Future<void> _createDebtSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS customers_local (
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
CREATE TABLE IF NOT EXISTS receivables_local (
  id TEXT PRIMARY KEY NOT NULL,
  customer_id TEXT NOT NULL,
  original_amount TEXT NOT NULL,
  outstanding_amount TEXT NOT NULL,
  due_date TEXT,
  note TEXT,
  status TEXT NOT NULL,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (customer_id) REFERENCES customers_local(id) ON DELETE RESTRICT
)
''');
    await db.execute('''
CREATE TABLE IF NOT EXISTS receivable_payments_local (
  id TEXT PRIMARY KEY NOT NULL,
  receivable_id TEXT NOT NULL,
  amount TEXT NOT NULL,
  payment_method_label TEXT NOT NULL,
  local_operation_id TEXT NOT NULL UNIQUE,
  source_device_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at INTEGER NOT NULL,
  FOREIGN KEY (receivable_id) REFERENCES receivables_local(id) ON DELETE CASCADE
)
''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customers_local_name '
      'ON customers_local (name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_receivables_local_created_at '
      'ON receivables_local (created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_receivable_payments_receivable '
      'ON receivable_payments_local (receivable_id, created_at DESC)',
    );
  }

  SyncQueueRepository get syncQueue => SyncQueueRepository(this);

  /// Stable device id for idempotent sync (stored in [local_meta]).
  Future<String> getOrCreateDeviceId() async {
    const key = 'device_id';
    final db = await database;
    final rows =
        await db.query('local_meta', where: 'key = ?', whereArgs: [key]);
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
