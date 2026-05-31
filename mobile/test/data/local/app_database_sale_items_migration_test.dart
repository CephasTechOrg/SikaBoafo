import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Set<String>> _saleItemColumnNames(Database db) async {
  final rows = await db.rawQuery('PRAGMA table_info(sale_items_local)');
  return rows.map((r) => (r['name'] ?? '').toString()).toSet();
}

Future<void> _ensureSaleItemsVariantColumns(Database db) async {
  final saleCols = await db.rawQuery('PRAGMA table_info(sale_items_local)');
  final saleColNames =
      saleCols.map((r) => (r['name'] ?? '').toString()).toSet();
  if (!saleColNames.contains('variant_id')) {
    await db.execute('ALTER TABLE sale_items_local ADD COLUMN variant_id TEXT');
  }
  if (!saleColNames.contains('variant_label')) {
    await db
        .execute('ALTER TABLE sale_items_local ADD COLUMN variant_label TEXT');
  }
}

void main() {
  test('v20 migration adds variant columns missing from legacy sale_items_local',
      () async {
    sqfliteFfiInit();
    final dbPath = p.join(
      (await databaseFactoryFfi.getDatabasesPath()),
      'migration_test_v19.db',
    );
    await databaseFactoryFfi.deleteDatabase(dbPath);

    final v19db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 19,
        onCreate: (db, version) async {
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
    await v19db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 20,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 20) {
            await _ensureSaleItemsVariantColumns(db);
          }
        },
      ),
    );

    final cols = await _saleItemColumnNames(upgraded);
    expect(cols, containsAll(['variant_id', 'variant_label']));
    await upgraded.close();
    await databaseFactoryFfi.deleteDatabase(dbPath);
  });
}
