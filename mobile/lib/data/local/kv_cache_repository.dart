import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class KvCacheRepository {
  KvCacheRepository(this._appDb);

  static const kInventoryTs = 'last_synced_inventory';
  static const kDebtsTs = 'last_synced_debts';
  static const kSalesTs = 'last_synced_sales';

  final AppDatabase _appDb;

  Future<void> putTimestamp(String key, DateTime dt) =>
      put(key, '"${dt.toUtc().toIso8601String()}"');

  Future<DateTime?> getTimestamp(String key) async {
    final raw = await get(key);
    if (raw == null) return null;
    final inner = raw.length >= 2 ? raw.substring(1, raw.length - 1) : raw;
    return DateTime.tryParse(inner)?.toLocal();
  }

  Future<void> put(String key, String valueJson) async {
    final db = await _appDb.database;
    await db.insert(
      'kv_cache',
      {
        'key': key,
        'value_json': valueJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> get(String key) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'kv_cache',
      columns: ['value_json'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value_json'] as String?;
  }
}

