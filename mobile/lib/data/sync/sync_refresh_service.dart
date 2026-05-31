import 'package:sqflite/sqflite.dart';

import '../local/app_database.dart';
import '../local/kv_cache_repository.dart';
import '../remote/sync_api.dart';
import '../../features/debts/data/debts_api.dart';
import '../../features/inventory/data/inventory_api.dart';

class SyncRefreshService {
  SyncRefreshService({
    required AppDatabase appDb,
    required SyncApi syncApi,
    required DebtsApi debtsApi,
  })  : _appDb = appDb,
        _syncApi = syncApi,
        _debtsApi = debtsApi;

  final AppDatabase _appDb;
  final SyncApi _syncApi;
  final DebtsApi _debtsApi;

  Future<void> refreshInventorySnapshot() async {
    await _pullAndApply(includeInventory: true, includeDebts: false);
  }

  Future<void> refreshDebtSnapshot() async {
    await _pullAndApply(includeInventory: false, includeDebts: true);
  }

  /// Single round-trip when both domains need reconciliation (e.g. sync conflicts).
  Future<void> refreshInventoryAndDebtSnapshots() async {
    await _pullAndApply(includeInventory: true, includeDebts: true);
  }

  Future<void> _pullAndApply({
    required bool includeInventory,
    required bool includeDebts,
  }) async {
    final since =
        await _appDb.kv.getTimestamp(KvCacheRepository.kSyncPullCursor);
    final includeParts = <String>[];
    if (includeInventory) includeParts.add('inventory');
    if (includeDebts) includeParts.add('debts');

    final pull = await _syncApi.pull(
      since: since,
      include: includeParts.join(','),
    );

    if (includeInventory && pull.inventory.isNotEmpty) {
      await _mergeInventory(pull.inventory);
    } else if (includeInventory && pull.fullRefresh) {
      await _mergeInventory(const []);
    }

    if (includeDebts &&
        (pull.customers.isNotEmpty ||
            pull.receivables.isNotEmpty ||
            pull.fullRefresh)) {
      await _mergeDebts(
        customers: pull.customers,
        receivables: pull.receivables,
        fullRefresh: pull.fullRefresh,
      );
    }

    await _appDb.kv.putTimestamp(
      KvCacheRepository.kSyncPullCursor,
      pull.cursor,
    );
    if (includeInventory) {
      await _appDb.kv.putTimestamp(
        KvCacheRepository.kInventoryTs,
        pull.cursor,
      );
    }
    if (includeDebts) {
      await _appDb.kv.putTimestamp(KvCacheRepository.kDebtsTs, pull.cursor);
    }
  }

  Future<void> _mergeInventory(List<Map<String, dynamic>> rows) async {
    final items = rows.map(InventoryItemDto.fromJson).toList(growable: false);
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

  Future<void> _mergeDebts({
    required List<Map<String, dynamic>> customers,
    required List<Map<String, dynamic>> receivables,
    required bool fullRefresh,
  }) async {
    var customerDtos =
        customers.map(DebtCustomerDto.fromJson).toList(growable: false);
    var receivableDtos =
        receivables.map(ReceivableDto.fromJson).toList(growable: false);

    if (fullRefresh && receivableDtos.isEmpty) {
      receivableDtos = await _debtsApi.fetchReceivables(
        limit: DebtsApi.maxReceivablesListQueryLimit,
      );
    }
    if (fullRefresh && customerDtos.isEmpty) {
      customerDtos = await _debtsApi.fetchCustomers();
    }

    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final fetchedIds = receivableDtos.map((r) => r.receivableId).toSet();

    // Backfill rows that can be missing from paged list responses (older but
    // still active debts, or rows with a still-shared payment link).
    final trackedRows = await db.query(
      'receivables_local',
      columns: ['id'],
      where: "status IN (?, ?) OR payment_link IS NOT NULL",
      whereArgs: ['open', 'partially_paid'],
    );
    final trackedIds = trackedRows
        .map((row) => (row['id'] ?? '').toString())
        .where((id) => id.isNotEmpty && !fetchedIds.contains(id))
        .toList(growable: false);
    final extraReceivables = <ReceivableDto>[];
    for (final id in trackedIds) {
      try {
        final dto = await _debtsApi.fetchReceivable(id);
        extraReceivables.add(dto);
      } catch (_) {
        // Ignore per-row lookup failures so a single missing/deleted row does
        // not block the entire debt snapshot refresh.
      }
    }
    final allReceivables = <ReceivableDto>[
      ...receivableDtos,
      ...extraReceivables,
    ];

    await db.transaction((tx) async {
      for (final customer in customerDtos) {
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

      for (final receivable in allReceivables) {
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
          'whatsapp_number': dto.whatsappNumber,
          'email': dto.email,
          'notes': dto.notes,
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
        'whatsapp_number': dto.whatsappNumber,
        'email': dto.email,
        'notes': dto.notes,
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
          'invoice_number': dto.invoiceNumber,
          'payment_link': dto.paymentLink,
          'payment_id': dto.paymentId,
          'payment_amount': dto.paymentAmount,
          'payment_link_expires_at': dto.paymentLinkExpiresAtIso,
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
        'invoice_number': dto.invoiceNumber,
        'payment_link': dto.paymentLink,
        'payment_id': dto.paymentId,
        'payment_amount': dto.paymentAmount,
        'payment_link_expires_at': dto.paymentLinkExpiresAtIso,
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
