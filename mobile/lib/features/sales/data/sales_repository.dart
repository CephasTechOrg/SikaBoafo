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

class LocalSaleRecord {
  const LocalSaleRecord({
    required this.saleId,
    required this.totalAmount,
    required this.paymentMethodLabel,
    required this.syncStatus,
    required this.createdAtMillis,
  });

  final String saleId;
  final String totalAmount;
  final String paymentMethodLabel;
  final String syncStatus;
  final int createdAtMillis;

  factory LocalSaleRecord.fromRow(Map<String, Object?> row) {
    return LocalSaleRecord(
      saleId: (row['id'] ?? '') as String,
      totalAmount: (row['total_amount'] ?? '0.00') as String,
      paymentMethodLabel: (row['payment_method_label'] ?? 'cash') as String,
      syncStatus: (row['sync_status'] ?? 'pending') as String,
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

  static const _allowedPaymentMethods = {'cash', 'mobile_money', 'bank_transfer'};

  Future<List<LocalSaleRecord>> listRecentSales({int limit = 30}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT s.id, s.total_amount, s.payment_method_label, s.created_at,
       COALESCE(q.status, s.status) AS sync_status
FROM sales_local s
LEFT JOIN sync_queue q
  ON q.local_operation_id = s.local_operation_id
 AND q.source_device_id = s.source_device_id
ORDER BY s.created_at DESC
LIMIT ?
''',
      [limit],
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
