import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../data/sync/sync_queue_runner.dart';
import 'inventory_api.dart';
import 'local_variant.dart';

const archiveRequiresZeroStockMessage =
    'Adjust stock to 0 before archiving this item.';

class LocalInventoryItem {
  const LocalInventoryItem({
    required this.id,
    required this.name,
    required this.defaultPrice,
    required this.quantityOnHand,
    this.sku,
    this.category,
    this.lowStockThreshold,
    this.isActive = true,
    this.imageUrl,
    this.serverVersion,
    this.variants = const [],
  });

  final String id;
  final String name;
  final String defaultPrice;
  final String? sku;
  final String? category;
  final int? lowStockThreshold;
  final bool isActive;
  final int quantityOnHand;
  final String? imageUrl;
  /// Version counter from the server, used for optimistic locking. Null means
  /// this row has not yet been synced from the server.
  final int? serverVersion;
  final List<LocalVariant> variants;

  bool get hasVariants => variants.isNotEmpty;

  factory LocalInventoryItem.fromRow(Map<String, Object?> row) {
    return LocalInventoryItem(
      id: (row['id'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      defaultPrice: (row['default_price'] ?? '0.00') as String,
      sku: row['sku'] as String?,
      category: row['category'] as String?,
      lowStockThreshold: row['low_stock_threshold'] as int?,
      isActive: (row['is_active'] as int? ?? 1) == 1,
      quantityOnHand: (row['quantity_on_hand'] as int? ?? 0),
      imageUrl: row['image_url'] as String?,
      serverVersion: row['server_version'] as int?,
    );
  }

  LocalInventoryItem withVariants(List<LocalVariant> variants) {
    return LocalInventoryItem(
      id: id,
      name: name,
      defaultPrice: defaultPrice,
      sku: sku,
      category: category,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
      quantityOnHand: quantityOnHand,
      imageUrl: imageUrl,
      serverVersion: serverVersion,
      variants: variants,
    );
  }
}

class SyncRunSummary {
  const SyncRunSummary({
    required this.applied,
    required this.failed,
  });

  final int applied;
  final int failed;
}

class InventoryRepository {
  InventoryRepository({
    required AppDatabase appDb,
    required InventoryApi inventoryApi,
    required SyncQueueRunner syncQueueRunner,
  })  : _appDb = appDb,
        _inventoryApi = inventoryApi,
        _syncQueueRunner = syncQueueRunner;

  final AppDatabase _appDb;
  final InventoryApi _inventoryApi;
  final SyncQueueRunner _syncQueueRunner;
  final _uuid = const Uuid();

  Future<List<LocalInventoryItem>> listLocalItems() async {
    final db = await _appDb.database;
    final rows = await db.query(
      'items_local',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    if (rows.isEmpty) return const [];
    final items = rows.map(LocalInventoryItem.fromRow).toList();
    final ids = items.map((i) => i.id).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final variantRows = await db.rawQuery(
      'SELECT * FROM item_variants_local WHERE item_id IN ($placeholders) '
      'AND is_active = 1 ORDER BY sort_order ASC',
      ids,
    );
    final variantsByItemId = <String, List<LocalVariant>>{};
    for (final vr in variantRows) {
      final v = LocalVariant.fromRow(vr);
      variantsByItemId.putIfAbsent(v.itemId, () => []).add(v);
    }
    return items
        .map((item) => item.withVariants(variantsByItemId[item.id] ?? []))
        .toList(growable: false);
  }

  Future<void> refreshFromServer() async {
    final items = await _inventoryApi.fetchItems();
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      for (final item in items) {
        await tx.insert(
          'items_local',
          {
            'id': item.itemId,
            'name': item.name,
            'default_price': item.defaultPrice,
            'sku': item.sku,
            'category': item.category,
            'low_stock_threshold': item.lowStockThreshold,
            'is_active': item.isActive ? 1 : 0,
            'quantity_on_hand': item.quantityOnHand,
            'image_url': item.imageUrl,
            'server_version': item.version,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        // Replace variants for this item
        await tx.delete('item_variants_local',
            where: 'item_id = ?', whereArgs: [item.itemId]);
        for (final v in item.variants) {
          await tx.insert('item_variants_local', v.toRow(item.itemId));
        }
      }
    });
    await _appDb.kv.putTimestamp(
        KvCacheRepository.kInventoryTs, DateTime.now().toUtc());
  }

  Future<void> createItemLocal({
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    int initialQuantity = 0,
    String? imageUrl,
    List<LocalVariant> variants = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('Item name must be at least 2 characters.');
    }
    final price = double.tryParse(defaultPrice.trim());
    if (price == null || price <= 0) {
      throw ArgumentError('Default price must be greater than 0.');
    }
    if (initialQuantity < 0) {
      throw ArgumentError('Initial quantity cannot be negative.');
    }

    final db = await _appDb.database;
    final itemId = _uuid.v4();
    final localOpId = _uuid.v4();
    final stockInOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    await db.transaction((tx) async {
      await tx.insert(
        'items_local',
        {
          'id': itemId,
          'name': cleanName,
          'default_price': defaultPrice.trim(),
          'sku': _cleanOptional(sku),
          'category': _cleanOptional(category),
          'low_stock_threshold': lowStockThreshold,
          'is_active': 1,
          'quantity_on_hand': initialQuantity,
          'image_url': imageUrl,
          'created_at': now,
          'updated_at': now,
        },
      );
      for (int i = 0; i < variants.length; i++) {
        await tx.insert(
            'item_variants_local', variants[i].toRow(itemId));
      }
      await _appDb.syncQueue.enqueue(
        entityType: 'item',
        operation: 'create',
        entityId: itemId,
        payloadJson: jsonEncode(
          {
            'item_id': itemId,
            'name': cleanName,
            'default_price': defaultPrice.trim(),
            'sku': _cleanOptional(sku),
            'category': _cleanOptional(category),
            'low_stock_threshold': lowStockThreshold,
            'image_url': imageUrl,
            if (variants.isNotEmpty)
              'variants': variants.map((v) => v.toSyncJson()).toList(),
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );

      if (initialQuantity > 0) {
        await tx.insert(
          'inventory_movements_local',
          {
            'id': _uuid.v4(),
            'item_id': itemId,
            'movement_type': 'stock_in',
            'quantity': initialQuantity,
            'reason': 'initial stock',
            'local_operation_id': stockInOpId,
            'created_at': now,
          },
        );
        await _appDb.syncQueue.enqueue(
          entityType: 'inventory',
          operation: 'stock_in',
          entityId: itemId,
          payloadJson: jsonEncode(
            {
              'item_id': itemId,
              'quantity': initialQuantity,
              'reason': 'initial stock',
            },
          ),
          sourceDeviceId: sourceDeviceId,
          localOperationId: stockInOpId,
          executor: tx,
        );
      }
    });
  }

  Future<void> updateItemLocal({
    required String itemId,
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    required bool isActive,
    String? imageUrl,
    bool imageUrlChanged = false,
    List<LocalVariant>? variants,
    bool variantsChanged = false,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('Item name must be at least 2 characters.');
    }
    final priceText = defaultPrice.trim();
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      throw ArgumentError('Default price must be greater than 0.');
    }
    if (lowStockThreshold != null && lowStockThreshold < 0) {
      throw ArgumentError('Low stock threshold cannot be negative.');
    }

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      final rows = await tx.query(
        'items_local',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError('Item not found.');
      }

      final current = LocalInventoryItem.fromRow(rows.first);
      if (!isActive && current.isActive && current.quantityOnHand > 0) {
        throw ArgumentError(archiveRequiresZeroStockMessage);
      }
      final payload = <String, Object?>{
        'item_id': itemId,
        if (current.serverVersion != null) 'version': current.serverVersion,
      };
      final updates = <String, Object?>{'updated_at': now};

      if (cleanName != current.name) {
        payload['name'] = cleanName;
        updates['name'] = cleanName;
      }
      if (priceText != current.defaultPrice) {
        payload['default_price'] = priceText;
        updates['default_price'] = priceText;
      }

      final nextSkuPayload = _normalizePatchText(sku);
      final currentSkuPayload = current.sku ?? '';
      if (nextSkuPayload != currentSkuPayload) {
        payload['sku'] = nextSkuPayload;
        updates['sku'] = nextSkuPayload.isEmpty ? null : nextSkuPayload;
      }

      final nextCategoryPayload = _normalizePatchText(category);
      final currentCategoryPayload = current.category ?? '';
      if (nextCategoryPayload != currentCategoryPayload) {
        payload['category'] = nextCategoryPayload;
        updates['category'] =
            nextCategoryPayload.isEmpty ? null : nextCategoryPayload;
      }

      if (lowStockThreshold != current.lowStockThreshold) {
        payload['low_stock_threshold'] = lowStockThreshold;
        updates['low_stock_threshold'] = lowStockThreshold;
      }

      if (isActive != current.isActive) {
        payload['is_active'] = isActive;
        updates['is_active'] = isActive ? 1 : 0;
      }

      if (imageUrlChanged && imageUrl != current.imageUrl) {
        payload['image_url'] = imageUrl;
        updates['image_url'] = imageUrl;
      }

      if (variantsChanged && variants != null) {
        payload['variants'] = variants.map((v) => v.toSyncJson()).toList();
        await tx.delete('item_variants_local',
            where: 'item_id = ?', whereArgs: [itemId]);
        for (int i = 0; i < variants.length; i++) {
          await tx.insert('item_variants_local', variants[i].toRow(itemId));
        }
      }

      final hasChanges = updates.length > 1 || variantsChanged;
      if (!hasChanges) {
        throw ArgumentError('No item changes to save.');
      }

      await tx.update(
        'items_local',
        updates,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      final serverPayloadKeys =
          payload.keys.where((k) => k != 'item_id' && k != 'version');
      if (serverPayloadKeys.isNotEmpty) {
        await _appDb.syncQueue.enqueue(
          entityType: 'item',
          operation: 'update',
          entityId: itemId,
          payloadJson: jsonEncode(payload),
          sourceDeviceId: sourceDeviceId,
          localOperationId: localOpId,
          executor: tx,
        );
      }
    });
  }

  Future<void> archiveItemLocal({required String itemId}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'items_local',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('Item not found.');
    }
    final item = LocalInventoryItem.fromRow(rows.first);
    await updateItemLocal(
      itemId: itemId,
      name: item.name,
      defaultPrice: item.defaultPrice,
      sku: item.sku,
      category: item.category,
      lowStockThreshold: item.lowStockThreshold,
      isActive: false,
      imageUrl: item.imageUrl,
    );
  }

  Future<void> restoreItemLocal({required String itemId}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'items_local',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('Item not found.');
    }
    final item = LocalInventoryItem.fromRow(rows.first);
    await updateItemLocal(
      itemId: itemId,
      name: item.name,
      defaultPrice: item.defaultPrice,
      sku: item.sku,
      category: item.category,
      lowStockThreshold: item.lowStockThreshold,
      isActive: true,
      imageUrl: item.imageUrl,
    );
  }

  Future<void> stockInLocal({
    required String itemId,
    required int quantity,
    String? reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than 0.');
    }
    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final localOpId = _uuid.v4();
    final movementId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      final itemRows = await tx.query(
        'items_local',
        columns: ['quantity_on_hand', 'server_version'],
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (itemRows.isEmpty) throw ArgumentError('Item not found.');
      final current = (itemRows.first['quantity_on_hand'] as int? ?? 0);
      final serverVersion = itemRows.first['server_version'] as int?;
      final next = current + quantity;
      await tx.update(
        'items_local',
        {'quantity_on_hand': next, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await tx.insert(
        'inventory_movements_local',
        {
          'id': movementId,
          'item_id': itemId,
          'movement_type': 'stock_in',
          'quantity': quantity,
          'reason': _cleanOptional(reason),
          'local_operation_id': localOpId,
          'created_at': now,
        },
      );
      await _appDb.syncQueue.enqueue(
        entityType: 'inventory',
        operation: 'stock_in',
        entityId: itemId,
        payloadJson: jsonEncode(
          {
            'item_id': itemId,
            'quantity': quantity,
            'reason': _cleanOptional(reason),
            if (serverVersion != null) 'balance_version': serverVersion,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<void> adjustStockLocal({
    required String itemId,
    required int quantityDelta,
    String? reason,
  }) async {
    if (quantityDelta == 0) {
      throw ArgumentError('Adjustment delta cannot be 0.');
    }
    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final localOpId = _uuid.v4();
    final movementId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      final itemRows = await tx.query(
        'items_local',
        columns: ['quantity_on_hand', 'server_version'],
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (itemRows.isEmpty) throw ArgumentError('Item not found.');
      final current = (itemRows.first['quantity_on_hand'] as int? ?? 0);
      final serverVersion = itemRows.first['server_version'] as int?;
      final next = current + quantityDelta;
      if (next < 0) {
        throw ArgumentError('Adjustment would make stock negative.');
      }
      await tx.update(
        'items_local',
        {'quantity_on_hand': next, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await tx.insert(
        'inventory_movements_local',
        {
          'id': movementId,
          'item_id': itemId,
          'movement_type': 'adjustment',
          'quantity': quantityDelta,
          'reason': _cleanOptional(reason),
          'local_operation_id': localOpId,
          'created_at': now,
        },
      );
      await _appDb.syncQueue.enqueue(
        entityType: 'inventory',
        operation: 'adjust',
        entityId: itemId,
        payloadJson: jsonEncode(
          {
            'item_id': itemId,
            'quantity_delta': quantityDelta,
            'reason': _cleanOptional(reason),
            if (serverVersion != null) 'balance_version': serverVersion,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  /// Permanently deletes an archived item.
  ///
  /// If the item has been synced to the server (serverVersion != null), the
  /// DELETE is sent immediately — not queued — because it requires server
  /// confirmation (FK constraints / sales-history guard). On success the local
  /// row and any pending sync_queue entries for that item are removed.
  ///
  /// If the item was never synced (serverVersion == null) it is deleted locally
  /// only; no network call is made.
  Future<void> deleteItemLocal({required String itemId}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'items_local',
      columns: ['is_active', 'server_version'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) throw ArgumentError('Item not found.');
    final isActive = (rows.first['is_active'] as int? ?? 1) == 1;
    if (isActive) throw ArgumentError('Only archived items can be permanently deleted.');

    final serverVersion = rows.first['server_version'] as int?;
    if (serverVersion != null) {
      // Requires server confirmation — call API directly (not sync queue).
      await _inventoryApi.deleteItem(itemId);
    }

    await db.transaction((tx) async {
      await tx.delete('items_local', where: 'id = ?', whereArgs: [itemId]);
      await tx.delete('sync_queue', where: 'entity_id = ?', whereArgs: [itemId]);
    });
  }

  Future<SyncRunSummary> syncPendingQueue({int limit = 100}) async {
    final result = await _syncQueueRunner.run(limit: limit);
    return SyncRunSummary(applied: result.applied, failed: result.failed);
  }

  String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizePatchText(String? value) {
    return value?.trim() ?? '';
  }
}
