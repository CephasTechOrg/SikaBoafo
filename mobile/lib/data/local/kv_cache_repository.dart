import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

class KvCacheRepository {
  KvCacheRepository(this._appDb);

  final AppDatabase _appDb;

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

