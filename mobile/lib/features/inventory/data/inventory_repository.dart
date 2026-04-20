import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/sync/sync_queue_runner.dart';
import 'inventory_api.dart';

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
    this.imageAsset,
  });

  final String id;
  final String name;
  final String defaultPrice;
  final String? sku;
  final String? category;
  final int? lowStockThreshold;
  final bool isActive;
  final int quantityOnHand;
  final String? imageAsset;

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
      imageAsset: row['image_asset'] as String?,
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
    return rows.map(LocalInventoryItem.fromRow).toList(growable: false);
  }

  Future<void> refreshFromServer() async {
    final items = await _inventoryApi.fetchItems();
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((tx) async {
      for (final item in items) {
        // Preserve locally-chosen image_asset — it is not synced to the server.
        final existing = await tx.query(
          'items_local',
          columns: ['image_asset'],
          where: 'id = ?',
          whereArgs: [item.itemId],
          limit: 1,
        );
        final existingImage =
            existing.isNotEmpty ? existing.first['image_asset'] as String? : null;

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
            'image_asset': existingImage,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> createItemLocal({
    required String name,
    required String defaultPrice,
    String? sku,
    String? category,
    int? lowStockThreshold,
    int initialQuantity = 0,
    String? imageAsset,
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
          'image_asset': imageAsset,
          'created_at': now,
          'updated_at': now,
        },
      );
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
    String? imageAsset,
    bool imageAssetChanged = false,
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
      final payload = <String, Object?>{'item_id': itemId};
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

      var hasLocalOnlyChange = false;
      if (imageAssetChanged && imageAsset != current.imageAsset) {
        // image_asset is local-only — stored locally but not synced to server.
        updates['image_asset'] = imageAsset;
        hasLocalOnlyChange = true;
      }

      if (payload.length == 1 && !hasLocalOnlyChange) {
        throw ArgumentError('No item changes to save.');
      }

      await tx.update(
        'items_local',
        updates,
        where: 'id = ?',
        whereArgs: [itemId],
      );
      // Only sync if there are server-visible field changes (payload > item_id).
      if (payload.length > 1) {
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
      imageAsset: item.imageAsset,
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
      imageAsset: item.imageAsset,
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
      final current = await _itemQuantity(tx: tx, itemId: itemId);
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
      final current = await _itemQuantity(tx: tx, itemId: itemId);
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
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<SyncRunSummary> syncPendingQueue({int limit = 100}) async {
    final result = await _syncQueueRunner.run(limit: limit);
    return SyncRunSummary(applied: result.applied, failed: result.failed);
  }

  Future<int> _itemQuantity({
    required Transaction tx,
    required String itemId,
  }) async {
    final rows = await tx.query(
      'items_local',
      columns: ['quantity_on_hand'],
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw ArgumentError('Item not found.');
    }
    return (rows.first['quantity_on_hand'] as int? ?? 0);
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
