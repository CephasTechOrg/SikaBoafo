import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../../features/debts/data/debts_api.dart';
import '../../features/inventory/data/inventory_api.dart';

class SyncRefreshService {
  SyncRefreshService({
    required AppDatabase appDb,
    required InventoryApi inventoryApi,
    required DebtsApi debtsApi,
  })  : _appDb = appDb,
        _inventoryApi = inventoryApi,
        _debtsApi = debtsApi;

  final AppDatabase _appDb;
  final InventoryApi _inventoryApi;
  final DebtsApi _debtsApi;

  Future<void> refreshInventorySnapshot() async {
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
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> refreshDebtSnapshot() async {
    final customers = await _debtsApi.fetchCustomers();
    final receivables = await _debtsApi.fetchReceivables();
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      for (final customer in customers) {
        final existing = await tx.query(
          'customers_local',
          columns: ['local_operation_id', 'source_device_id', 'created_at'],
          where: 'id = ?',
          whereArgs: [customer.customerId],
          limit: 1,
        );
        await _upsertCustomer(
          tx: tx,
          dto: customer,
          now: now,
          existing: existing.isEmpty ? null : existing.first,
        );
      }

      for (final receivable in receivables) {
        final existing = await tx.query(
          'receivables_local',
          columns: ['local_operation_id', 'source_device_id', 'created_at'],
          where: 'id = ?',
          whereArgs: [receivable.receivableId],
          limit: 1,
        );
        await _upsertReceivable(
          tx: tx,
          dto: receivable,
          now: now,
          existing: existing.isEmpty ? null : existing.first,
        );
      }
    });
  }

  Future<void> _upsertCustomer({
    required Transaction tx,
    required DebtCustomerDto dto,
    required int now,
    required Map<String, Object?>? existing,
  }) async {
    if (existing == null) {
      await tx.insert(
        'customers_local',
        {
          'id': dto.customerId,
          'name': dto.name,
          'phone_number': dto.phoneNumber,
          'local_operation_id': 'server:customer:${dto.customerId}',
          'source_device_id': 'server',
          'status': 'applied',
          'created_at': now,
          'updated_at': now,
        },
      );
      return;
    }

    await tx.update(
      'customers_local',
      {
        'name': dto.name,
        'phone_number': dto.phoneNumber,
        'status': 'applied',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [dto.customerId],
    );
  }

  Future<void> _upsertReceivable({
    required Transaction tx,
    required ReceivableDto dto,
    required int now,
    required Map<String, Object?>? existing,
  }) async {
    final createdAt = _parseCreatedAt(dto.createdAtIso, fallback: now);
    if (existing == null) {
      await tx.insert(
        'receivables_local',
        {
          'id': dto.receivableId,
          'customer_id': dto.customerId,
          'original_amount': dto.originalAmount,
          'outstanding_amount': dto.outstandingAmount,
          'due_date': dto.dueDateIso,
          'status': dto.status,
          'local_operation_id': 'server:receivable:${dto.receivableId}',
          'source_device_id': 'server',
          'created_at': createdAt,
          'updated_at': now,
        },
      );
      return;
    }

    await tx.update(
      'receivables_local',
      {
        'customer_id': dto.customerId,
        'original_amount': dto.originalAmount,
        'outstanding_amount': dto.outstandingAmount,
        'due_date': dto.dueDateIso,
        'status': dto.status,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [dto.receivableId],
    );
  }

  int _parseCreatedAt(String raw, {required int fallback}) {
    final parsed = DateTime.tryParse(raw);
    return parsed?.millisecondsSinceEpoch ?? fallback;
  }
}
