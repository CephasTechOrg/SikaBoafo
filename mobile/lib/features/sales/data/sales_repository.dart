import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/sync/sync_queue_runner.dart';

class SaleDraftLine {
  const SaleDraftLine({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
  });

  final String itemId;
  final int quantity;
  final String unitPrice;
}

class SaleQuantityUpdateDraft {
  const SaleQuantityUpdateDraft({
    required this.itemId,
    required this.quantity,
  });

  final String itemId;
  final int quantity;
}

class LocalSaleEditableLine {
  const LocalSaleEditableLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.maxQuantity,
  });

  final String itemId;
  final String itemName;
  final int quantity;
  final String unitPrice;
  final int maxQuantity;
}

class LocalSaleEditable {
  const LocalSaleEditable({
    required this.saleId,
    required this.paymentMethodLabel,
    required this.lines,
  });

  final String saleId;
  final String paymentMethodLabel;
  final List<LocalSaleEditableLine> lines;
}

class LocalSaleRecord {
  const LocalSaleRecord({
    required this.saleId,
    required this.totalAmount,
    required this.paymentMethodLabel,
    required this.syncStatus,
    required this.saleStatus,
    required this.voidedAtMillis,
    required this.voidReason,
    required this.createdAtMillis,
  });

  final String saleId;
  final String totalAmount;
  final String paymentMethodLabel;
  final String syncStatus;
  final String saleStatus;
  final int? voidedAtMillis;
  final String? voidReason;
  final int createdAtMillis;

  bool get isVoided => saleStatus == 'voided';

  factory LocalSaleRecord.fromRow(Map<String, Object?> row) {
    return LocalSaleRecord(
      saleId: (row['id'] ?? '') as String,
      totalAmount: (row['total_amount'] ?? '0.00') as String,
      paymentMethodLabel: (row['payment_method_label'] ?? 'cash') as String,
      syncStatus: (row['sync_status'] ?? 'pending') as String,
      saleStatus: (row['sale_status'] ?? 'recorded') as String,
      voidedAtMillis: row['voided_at'] as int?,
      voidReason: row['void_reason'] as String?,
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}

class SalesRepository {
  SalesRepository({
    required AppDatabase appDb,
    required SyncQueueRunner syncQueueRunner,
  })  : _appDb = appDb,
        _syncQueueRunner = syncQueueRunner;

  final AppDatabase _appDb;
  final SyncQueueRunner _syncQueueRunner;
  final _uuid = const Uuid();

  static const _allowedPaymentMethods = {
    'cash',
    'mobile_money',
    'bank_transfer'
  };

  Future<List<LocalSaleRecord>> listRecentSales({
    int limit = 30,
    bool includeVoided = false,
  }) async {
    final db = await _appDb.database;
    final whereClause = includeVoided ? '' : 'WHERE s.sale_status != ?';
    final args = includeVoided ? <Object?>[limit] : <Object?>['voided', limit];
    final rows = await db.rawQuery(
      '''
SELECT s.id, s.total_amount, s.payment_method_label, s.sale_status,
       s.voided_at, s.void_reason, s.created_at,
       COALESCE(q.status, s.status) AS sync_status
FROM sales_local s
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
$whereClause
ORDER BY s.created_at DESC
LIMIT ?
''',
      args,
    );
    return rows.map(LocalSaleRecord.fromRow).toList(growable: false);
  }

  Future<void> createSaleLocal({
    required String paymentMethodLabel,
    required List<SaleDraftLine> lines,
  }) async {
    final method = paymentMethodLabel.trim().toLowerCase();
    if (!_allowedPaymentMethods.contains(method)) {
      throw ArgumentError('Unsupported payment method: $paymentMethodLabel');
    }
    if (lines.isEmpty) {
      throw ArgumentError('At least one sale line is required.');
    }

    final aggregatedLines = _aggregateLines(lines);
    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final saleId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      int totalMinor = 0;
      final snapshotRows = <_SalePreparedLine>[];
      for (final line in aggregatedLines) {
        final itemRows = await tx.query(
          'items_local',
          columns: ['id', 'quantity_on_hand', 'updated_at'],
          where: 'id = ?',
          whereArgs: [line.itemId],
          limit: 1,
        );
        if (itemRows.isEmpty) {
          throw ArgumentError('Item not found: ${line.itemId}');
        }
        final itemRow = itemRows.first;
        final available = (itemRow['quantity_on_hand'] as int? ?? 0);
        if (available < line.quantity) {
          throw ArgumentError(
            'Insufficient stock for item ${line.itemId}. '
            'Available: $available, requested: ${line.quantity}.',
          );
        }

        final lineTotalMinor = line.unitPriceMinor * line.quantity;
        totalMinor += lineTotalMinor;
        snapshotRows.add(
          _SalePreparedLine(
            itemId: line.itemId,
            quantity: line.quantity,
            unitPriceMinor: line.unitPriceMinor,
            lineTotalMinor: lineTotalMinor,
            nextQuantityOnHand: available - line.quantity,
          ),
        );
      }

      await tx.insert(
        'sales_local',
        {
          'id': saleId,
          'payment_method_label': method,
          'total_amount': _minorToMoney(totalMinor),
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'status': 'pending',
          'created_at': now,
        },
      );

      for (final line in snapshotRows) {
        await tx.update(
          'items_local',
          {
            'quantity_on_hand': line.nextQuantityOnHand,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [line.itemId],
        );
        await tx.insert(
          'sale_items_local',
          {
            'id': _uuid.v4(),
            'sale_id': saleId,
            'item_id': line.itemId,
            'quantity': line.quantity,
            'unit_price': _minorToMoney(line.unitPriceMinor),
            'line_total': _minorToMoney(line.lineTotalMinor),
            'created_at': now,
          },
        );
        await tx.insert(
          'inventory_movements_local',
          {
            'id': _uuid.v4(),
            'item_id': line.itemId,
            'movement_type': 'sale',
            'quantity': -line.quantity,
            'reason': 'sale recorded',
            'local_operation_id': localOpId,
            'created_at': now,
          },
        );
      }

      await _appDb.syncQueue.enqueue(
        entityType: 'sale',
        operation: 'create',
        entityId: saleId,
        payloadJson: jsonEncode(
          {
            'sale_id': saleId,
            'payment_method_label': method,
            'lines': [
              for (final line in snapshotRows)
                {
                  'item_id': line.itemId,
                  'quantity': line.quantity,
                  'unit_price': _minorToMoney(line.unitPriceMinor),
                },
            ],
          },
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<LocalSaleEditable?> loadSaleEditable({required String saleId}) async {
    final db = await _appDb.database;
    final saleRows = await db.query(
      'sales_local',
      columns: ['id', 'payment_method_label', 'sale_status'],
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (saleRows.isEmpty) {
      return null;
    }
    final saleRow = saleRows.first;
    final saleStatus = (saleRow['sale_status'] ?? 'recorded') as String;
    if (saleStatus == 'voided') {
      return null;
    }

    final lineRows = await db.rawQuery(
      '''
SELECT sl.item_id, sl.quantity, sl.unit_price,
       COALESCE(i.name, 'Item') AS item_name,
       COALESCE(i.quantity_on_hand, 0) AS quantity_on_hand
FROM sale_items_local sl
LEFT JOIN items_local i ON i.id = sl.item_id
WHERE sl.sale_id = ?
ORDER BY sl.created_at ASC
''',
      [saleId],
    );
    if (lineRows.isEmpty) {
      return null;
    }

    final lines = lineRows.map((row) {
      final quantity = (row['quantity'] as int? ?? 0);
      final available = (row['quantity_on_hand'] as int? ?? 0);
      return LocalSaleEditableLine(
        itemId: (row['item_id'] ?? '') as String,
        itemName: (row['item_name'] ?? 'Item') as String,
        quantity: quantity,
        unitPrice: (row['unit_price'] ?? '0.00') as String,
        maxQuantity: quantity + available,
      );
    }).toList(growable: false);

    return LocalSaleEditable(
      saleId: (saleRow['id'] ?? '') as String,
      paymentMethodLabel: (saleRow['payment_method_label'] ?? 'cash') as String,
      lines: lines,
    );
  }

  Future<void> updateSaleLocal({
    required String saleId,
    required String paymentMethodLabel,
    required List<SaleQuantityUpdateDraft> lines,
  }) async {
    final method = paymentMethodLabel.trim().toLowerCase();
    if (!_allowedPaymentMethods.contains(method)) {
      throw ArgumentError('Unsupported payment method: $paymentMethodLabel');
    }
    if (lines.isEmpty) {
      throw ArgumentError('At least one sale line is required.');
    }

    final byItem = <String, int>{};
    for (final line in lines) {
      if (line.itemId.trim().isEmpty) {
        throw ArgumentError('Sale line item_id is required.');
      }
      if (line.quantity <= 0) {
        throw ArgumentError('Sale quantity must be greater than 0.');
      }
      if (byItem.containsKey(line.itemId)) {
        throw ArgumentError('Duplicate sale line item: ${line.itemId}');
      }
      byItem[line.itemId] = line.quantity;
    }

    final db = await _appDb.database;
    await db.transaction((tx) async {
      final saleRows = await tx.query(
        'sales_local',
        columns: ['id', 'source_device_id', 'sale_status'],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) {
        throw ArgumentError('Sale not found: $saleId');
      }
      final saleRow = saleRows.first;
      if ((saleRow['sale_status'] ?? 'recorded') == 'voided') {
        throw ArgumentError('Cannot edit a voided sale.');
      }

      final lineRows = await tx.query(
        'sale_items_local',
        columns: ['id', 'item_id', 'quantity', 'unit_price'],
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      if (lineRows.isEmpty) {
        throw StateError('Cannot edit sale without line items.');
      }

      final existingByItem = <String, Map<String, Object?>>{};
      for (final row in lineRows) {
        final itemId = (row['item_id'] ?? '') as String;
        existingByItem[itemId] = row;
      }
      if (existingByItem.length != byItem.length ||
          existingByItem.keys.any((key) => !byItem.containsKey(key))) {
        throw ArgumentError(
          'Sale edit can only update quantities for the existing sale items.',
        );
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final sourceDeviceId =
          (saleRow['source_device_id'] as String?)?.trim().isNotEmpty == true
              ? (saleRow['source_device_id'] as String)
              : await _appDb.getOrCreateDeviceId();
      final localOpId = _uuid.v4();

      int totalMinor = 0;
      final queueLines = <Map<String, Object?>>[];
      for (final entry in existingByItem.entries) {
        final itemId = entry.key;
        final row = entry.value;
        final newQty = byItem[itemId] ?? 0;
        final oldQty = (row['quantity'] as int? ?? 0);
        final delta = newQty - oldQty;
        final unitPrice = (row['unit_price'] ?? '0.00') as String;
        final unitMinor = _moneyToMinor(unitPrice);

        final itemRows = await tx.query(
          'items_local',
          columns: ['quantity_on_hand'],
          where: 'id = ?',
          whereArgs: [itemId],
          limit: 1,
        );
        if (itemRows.isEmpty) {
          throw ArgumentError('Item not found: $itemId');
        }
        final available = (itemRows.first['quantity_on_hand'] as int? ?? 0);
        if (delta > 0 && available < delta) {
          throw ArgumentError(
            'Insufficient stock for item $itemId. '
            'Available: $available, requested extra: $delta.',
          );
        }

        final lineTotalMinor = unitMinor * newQty;
        totalMinor += lineTotalMinor;
        queueLines.add({
          'item_id': itemId,
          'quantity': newQty,
          'unit_price': unitPrice,
        });

        await tx.update(
          'sale_items_local',
          {
            'quantity': newQty,
            'line_total': _minorToMoney(lineTotalMinor),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );

        if (delta != 0) {
          await tx.update(
            'items_local',
            {
              'quantity_on_hand': available - delta,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [itemId],
          );
          await tx.insert(
            'inventory_movements_local',
            {
              'id': _uuid.v4(),
              'item_id': itemId,
              'movement_type': 'adjustment',
              'quantity': -delta,
              'reason': 'sale updated',
              'local_operation_id': localOpId,
              'created_at': now,
            },
          );
        }
      }

      await tx.update(
        'sales_local',
        {
          'payment_method_label': method,
          'total_amount': _minorToMoney(totalMinor),
          'sale_status': 'recorded',
          'voided_at': null,
          'void_reason': null,
          'local_operation_id': localOpId,
          'status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'sale',
        operation: 'update',
        entityId: saleId,
        payloadJson: jsonEncode(
          {
            'sale_id': saleId,
            'payment_method_label': method,
            'lines': queueLines,
          },
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<void> voidSaleLocal({
    required String saleId,
    String? reason,
  }) async {
    final trimmedReason = reason?.trim();
    final normalizedReason =
        (trimmedReason == null || trimmedReason.isEmpty) ? null : trimmedReason;

    final db = await _appDb.database;
    await db.transaction((tx) async {
      final saleRows = await tx.query(
        'sales_local',
        columns: ['id', 'source_device_id', 'sale_status'],
        where: 'id = ?',
        whereArgs: [saleId],
        limit: 1,
      );
      if (saleRows.isEmpty) {
        throw ArgumentError('Sale not found: $saleId');
      }
      final saleRow = saleRows.first;
      if ((saleRow['sale_status'] ?? 'recorded') == 'voided') {
        throw ArgumentError('Sale is already voided.');
      }

      final lineRows = await tx.query(
        'sale_items_local',
        columns: ['item_id', 'quantity'],
        where: 'sale_id = ?',
        whereArgs: [saleId],
      );
      if (lineRows.isEmpty) {
        throw StateError('Cannot void sale without line items.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final sourceDeviceId =
          (saleRow['source_device_id'] as String?)?.trim().isNotEmpty == true
              ? (saleRow['source_device_id'] as String)
              : await _appDb.getOrCreateDeviceId();
      final localOpId = _uuid.v4();

      for (final line in lineRows) {
        final itemId = (line['item_id'] ?? '') as String;
        final qty = (line['quantity'] as int? ?? 0);
        final itemRows = await tx.query(
          'items_local',
          columns: ['quantity_on_hand'],
          where: 'id = ?',
          whereArgs: [itemId],
          limit: 1,
        );
        if (itemRows.isEmpty) {
          throw ArgumentError('Item not found: $itemId');
        }
        final available = (itemRows.first['quantity_on_hand'] as int? ?? 0);
        await tx.update(
          'items_local',
          {
            'quantity_on_hand': available + qty,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [itemId],
        );
        await tx.insert(
          'inventory_movements_local',
          {
            'id': _uuid.v4(),
            'item_id': itemId,
            'movement_type': 'adjustment',
            'quantity': qty,
            'reason': normalizedReason ?? 'sale voided',
            'local_operation_id': localOpId,
            'created_at': now,
          },
        );
      }

      await tx.update(
        'sales_local',
        {
          'sale_status': 'voided',
          'voided_at': now,
          'void_reason': normalizedReason,
          'local_operation_id': localOpId,
          'status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'sale',
        operation: 'void',
        entityId: saleId,
        payloadJson: jsonEncode(
          {
            'sale_id': saleId,
            if (normalizedReason != null) 'reason': normalizedReason,
          },
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<SyncQueueRunSummary> syncPendingQueue({int limit = 100}) {
    return _syncQueueRunner.run(limit: limit);
  }

  List<_SaleLineAggregate> _aggregateLines(List<SaleDraftLine> lines) {
    final byItem = <String, _SaleLineAggregate>{};
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw ArgumentError('Sale quantity must be greater than 0.');
      }
      final unitMinor = _moneyToMinor(line.unitPrice);
      final existing = byItem[line.itemId];
      if (existing == null) {
        byItem[line.itemId] = _SaleLineAggregate(
          itemId: line.itemId,
          quantity: line.quantity,
          unitPriceMinor: unitMinor,
        );
        continue;
      }
      if (existing.unitPriceMinor != unitMinor) {
        throw ArgumentError('Conflicting prices for item ${line.itemId}.');
      }
      final mergedQty = existing.quantity + line.quantity;
      byItem[line.itemId] = _SaleLineAggregate(
        itemId: line.itemId,
        quantity: mergedQty,
        unitPriceMinor: unitMinor,
      );
    }
    return byItem.values.toList(growable: false);
  }

  int _moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) {
      throw ArgumentError('Invalid money value: $value');
    }
    final parts = raw.split('.');
    final major = int.parse(parts[0]);
    final decimal = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (major * 100) + int.parse(decimal);
  }

  String _minorToMoney(int value) {
    final major = value ~/ 100;
    final minor = (value % 100).toString().padLeft(2, '0');
    return '$major.$minor';
  }
}

class _SaleLineAggregate {
  const _SaleLineAggregate({
    required this.itemId,
    required this.quantity,
    required this.unitPriceMinor,
  });

  final String itemId;
  final int quantity;
  final int unitPriceMinor;
}

class _SalePreparedLine {
  const _SalePreparedLine({
    required this.itemId,
    required this.quantity,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
    required this.nextQuantityOnHand,
  });

  final String itemId;
  final int quantity;
  final int unitPriceMinor;
  final int lineTotalMinor;
  final int nextQuantityOnHand;
}
