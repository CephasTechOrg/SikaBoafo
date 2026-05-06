import 'dart:convert';

import '../../../data/local/app_database.dart';

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    required this.route,
    required this.createdAtMs,
    required this.isRead,
    this.entityId,
    this.payloadJson,
  });

  final int id;
  final int notificationId;
  final String type;
  final String title;
  final String body;
  final String route;
  final String? entityId;
  final String? payloadJson;
  final int createdAtMs;
  final bool isRead;

  Map<String, dynamic> toJson() => {
        'id': id,
        'notificationId': notificationId,
        'type': type,
        'title': title,
        'body': body,
        'route': route,
        'entityId': entityId,
        'createdAtMs': createdAtMs,
        'isRead': isRead,
        if (payloadJson != null) 'payload': jsonDecode(payloadJson!),
      };

  static InboxNotification fromRow(Map<String, Object?> row) {
    final id = (row['id'] as int?) ?? 0;
    final notificationId = (row['notification_id'] as int?) ?? 0;
    final type = (row['type'] as String?) ?? 'unknown';
    final title = (row['title'] as String?) ?? '';
    final body = (row['body'] as String?) ?? '';
    final route = (row['route'] as String?) ?? '/home';
    final entityId = row['entity_id'] as String?;
    final payloadJson = row['payload_json'] as String?;
    final createdAt = (row['created_at'] as int?) ?? 0;
    final readAt = row['read_at'] as int?;
    return InboxNotification(
      id: id,
      notificationId: notificationId,
      type: type,
      title: title,
      body: body,
      route: route,
      entityId: entityId,
      payloadJson: payloadJson,
      createdAtMs: createdAt,
      isRead: readAt != null && readAt > 0,
    );
  }
}

class NotificationsInboxRepository {
  NotificationsInboxRepository(this._db);

  final AppDatabase _db;

  Future<List<InboxNotification>> list({int limit = 200}) async {
    final db = await _db.database;
    final rows = await db.query(
      'notifications_local',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(InboxNotification.fromRow).toList(growable: false);
  }

  Future<int> unreadCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
SELECT COUNT(*) AS c
FROM notifications_local
WHERE deleted_at IS NULL AND (read_at IS NULL OR read_at = 0)
''');
    final first = rows.isEmpty ? null : rows.first;
    return (first?['c'] as int?) ?? 0;
  }

  Future<void> upsertFromLocalNotification({
    required int notificationId,
    required String type,
    required String title,
    required String body,
    required String route,
    String? entityId,
    String? payloadJson,
    int? createdAtMs,
  }) async {
    final db = await _db.database;
    final now = createdAtMs ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'notifications_local',
      {
        'notification_id': notificationId,
        'type': type,
        'title': title,
        'body': body,
        'route': route,
        'entity_id': entityId,
        'payload_json': payloadJson,
        'created_at': now,
        'read_at': null,
        'deleted_at': null,
      },
    );
  }

  Future<void> markRead(int id) async {
    final db = await _db.database;
    await db.update(
      'notifications_local',
      {'read_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead() async {
    final db = await _db.database;
    await db.update(
      'notifications_local',
      {'read_at': DateTime.now().millisecondsSinceEpoch},
      where: 'deleted_at IS NULL AND (read_at IS NULL OR read_at = 0)',
    );
  }

  Future<void> deleteOne(int id) async {
    final db = await _db.database;
    await db.update(
      'notifications_local',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.update(
      'notifications_local',
      {'deleted_at': DateTime.now().millisecondsSinceEpoch},
      where: 'deleted_at IS NULL',
    );
  }
}

