import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/sync/sync_queue_runner.dart';
import 'models/local_debt_customer.dart';
import 'models/local_receivable_detail.dart';
import 'models/local_receivable_payment_record.dart';
import 'models/local_receivable_record.dart';

// Re-export models so existing imports through this file (used by
// `customers/` screens) keep resolving.
export 'models/local_debt_customer.dart';
export 'models/local_receivable_detail.dart';
export 'models/local_receivable_payment_record.dart';
export 'models/local_receivable_record.dart';

class DebtsRepository {
  DebtsRepository({
    required AppDatabase appDb,
    required SyncQueueRunner syncQueueRunner,
  })  : _appDb = appDb,
        _syncQueueRunner = syncQueueRunner;

  final AppDatabase _appDb;
  final SyncQueueRunner _syncQueueRunner;
  final _uuid = const Uuid();

  static const allowedPaymentMethods = <String>{
    'cash',
    'mobile_money',
    'bank_transfer',
  };

  // ---------------------------------------------------------------- customers

  Future<List<LocalDebtCustomer>> listCustomers({int limit = 200}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT c.id,
       c.name,
       c.phone_number,
       c.whatsapp_number,
       c.email,
       c.notes,
       c.created_at,
       c.status,
       COALESCE(q.status, c.status) AS sync_status,
       COALESCE((
         SELECT printf('%.2f', SUM(CAST(r.outstanding_amount AS REAL)))
         FROM receivables_local r
         WHERE r.customer_id = c.id
       ), '0.00') AS total_outstanding
FROM customers_local c
LEFT JOIN sync_queue q
  ON q.local_operation_id = c.local_operation_id
 AND q.source_device_id = c.source_device_id
ORDER BY c.name ASC
LIMIT ?
''',
      [limit],
    );
    return rows
        .map((row) => LocalDebtCustomer.fromRow(
              row,
              totalOutstanding:
                  (row['total_outstanding'] ?? '0.00') as String,
            ))
        .toList(growable: false);
  }

  Future<LocalDebtCustomer?> getCustomerById(String customerId) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT c.id,
       c.name,
       c.phone_number,
       c.whatsapp_number,
       c.email,
       c.notes,
       c.created_at,
       c.status,
       COALESCE(q.status, c.status) AS sync_status,
       COALESCE((
         SELECT printf('%.2f', SUM(CAST(r.outstanding_amount AS REAL)))
         FROM receivables_local r
         WHERE r.customer_id = c.id
       ), '0.00') AS total_outstanding
FROM customers_local c
LEFT JOIN sync_queue q
  ON q.local_operation_id = c.local_operation_id
 AND q.source_device_id = c.source_device_id
WHERE c.id = ?
LIMIT 1
''',
      [customerId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return LocalDebtCustomer.fromRow(
      row,
      totalOutstanding: (row['total_outstanding'] ?? '0.00') as String,
    );
  }

  Future<String> createCustomerLocal({
    required String name,
    String? phoneNumber,
    String? whatsappNumber,
    String? email,
    String? notes,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      throw ArgumentError('Customer name must be at least 2 characters.');
    }

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final customerId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanedPhone = _cleanOptional(phoneNumber);
    final cleanedWhatsapp = _cleanOptional(whatsappNumber);
    final cleanedEmail = _cleanOptional(email);
    final cleanedNotes = _cleanOptional(notes);

    await db.transaction((tx) async {
      await tx.insert(
        'customers_local',
        {
          'id': customerId,
          'name': trimmedName,
          'phone_number': cleanedPhone,
          'whatsapp_number': cleanedWhatsapp,
          'email': cleanedEmail,
          'notes': cleanedNotes,
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'status': 'pending',
          'created_at': now,
          'updated_at': now,
        },
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'customer',
        operation: 'create',
        entityId: customerId,
        payloadJson: jsonEncode(
          {
            'customer_id': customerId,
            'name': trimmedName,
            'phone_number': cleanedPhone,
            'whatsapp_number': cleanedWhatsapp,
            'email': cleanedEmail,
            'notes': cleanedNotes,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });

    return customerId;
  }

  // -------------------------------------------------------------- receivables

  Future<List<LocalReceivableRecord>> listReceivables({int limit = 200}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT r.id,
       r.customer_id,
       c.name AS customer_name,
       r.original_amount,
       r.outstanding_amount,
       r.due_date,
       r.note,
       r.status,
       r.invoice_number,
       r.payment_link,
       r.payment_id,
       r.payment_amount,
       r.sale_id,
       r.created_by_user_id,
       r.created_at,
       COALESCE(q.status, 'applied') AS sync_status
FROM receivables_local r
LEFT JOIN customers_local c ON c.id = r.customer_id
LEFT JOIN sync_queue q
  ON q.local_operation_id = r.local_operation_id
 AND q.source_device_id = r.source_device_id
ORDER BY r.created_at DESC
LIMIT ?
''',
      [limit],
    );
    return rows.map(LocalReceivableRecord.fromRow).toList(growable: false);
  }

  Future<List<LocalReceivableRecord>> listReceivablesForCustomer(
    String customerId,
  ) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT r.id,
       r.customer_id,
       c.name AS customer_name,
       r.original_amount,
       r.outstanding_amount,
       r.due_date,
       r.note,
       r.status,
       r.invoice_number,
       r.payment_link,
       r.payment_id,
       r.payment_amount,
       r.sale_id,
       r.created_by_user_id,
       r.created_at,
       COALESCE(q.status, 'applied') AS sync_status
FROM receivables_local r
LEFT JOIN customers_local c ON c.id = r.customer_id
LEFT JOIN sync_queue q
  ON q.local_operation_id = r.local_operation_id
 AND q.source_device_id = r.source_device_id
WHERE r.customer_id = ?
ORDER BY r.created_at DESC
''',
      [customerId],
    );
    return rows.map(LocalReceivableRecord.fromRow).toList(growable: false);
  }

  Future<LocalReceivableRecord?> getReceivableById(String receivableId) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT r.id,
       r.customer_id,
       c.name AS customer_name,
       r.original_amount,
       r.outstanding_amount,
       r.due_date,
       r.note,
       r.status,
       r.invoice_number,
       r.payment_link,
       r.payment_id,
       r.payment_amount,
       r.sale_id,
       r.created_by_user_id,
       r.created_at,
       COALESCE(q.status, 'applied') AS sync_status
FROM receivables_local r
LEFT JOIN customers_local c ON c.id = r.customer_id
LEFT JOIN sync_queue q
  ON q.local_operation_id = r.local_operation_id
 AND q.source_device_id = r.source_device_id
WHERE r.id = ?
LIMIT 1
''',
      [receivableId],
    );
    if (rows.isEmpty) return null;
    return LocalReceivableRecord.fromRow(rows.first);
  }

  Future<LocalReceivableDetail?> getReceivableDetail(
    String receivableId,
  ) async {
    final receivable = await getReceivableById(receivableId);
    if (receivable == null) return null;
    final customer = await getCustomerById(receivable.customerId);
    if (customer == null) return null;
    final payments = await listPaymentsForReceivable(receivableId);
    return LocalReceivableDetail(
      receivable: receivable,
      customer: customer,
      payments: payments,
    );
  }

  Future<String> createReceivableLocal({
    required String customerId,
    required String originalAmount,
    String? dueDateIso,
    String? note,
  }) async {
    final amountMinor = _moneyToMinor(originalAmount);
    if (amountMinor <= 0) {
      throw ArgumentError('Debt amount must be greater than 0.');
    }
    final normalizedAmount = _minorToMoney(amountMinor);
    final cleanedNote = _cleanOptional(note);
    final cleanedDueDate = _cleanOptional(dueDateIso);

    final db = await _appDb.database;
    final customerExists = await db.query(
      'customers_local',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (customerExists.isEmpty) {
      throw ArgumentError('Customer not found.');
    }

    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final receivableId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      await tx.insert(
        'receivables_local',
        {
          'id': receivableId,
          'customer_id': customerId,
          'original_amount': normalizedAmount,
          'outstanding_amount': normalizedAmount,
          'due_date': cleanedDueDate,
          'note': cleanedNote,
          'status': 'open',
          'invoice_number': null,
          'payment_link': null,
          'payment_id': null,
          'payment_amount': null,
          'created_by_user_id': null,
          'sale_id': null,
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'created_at': now,
          'updated_at': now,
        },
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'receivable',
        operation: 'create',
        entityId: receivableId,
        payloadJson: jsonEncode(
          {
            'receivable_id': receivableId,
            'customer_id': customerId,
            'original_amount': normalizedAmount,
            'due_date': cleanedDueDate,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });

    return receivableId;
  }

  // ----------------------------------------------------- repayments (manual)

  Future<List<LocalReceivablePaymentRecord>> listPaymentsForReceivable(
    String receivableId,
  ) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT p.id,
       p.receivable_id,
       p.amount,
       p.payment_method_label,
       p.created_at,
       p.status,
       COALESCE(q.status, p.status) AS sync_status
FROM receivable_payments_local p
LEFT JOIN sync_queue q
  ON q.local_operation_id = p.local_operation_id
 AND q.source_device_id = p.source_device_id
WHERE p.receivable_id = ?
ORDER BY p.created_at DESC
''',
      [receivableId],
    );
    return rows
        .map(LocalReceivablePaymentRecord.fromRow)
        .toList(growable: false);
  }

  Future<String> recordRepaymentLocal({
    required String receivableId,
    required String amount,
    required String paymentMethodLabel,
  }) async {
    final method = paymentMethodLabel.trim().toLowerCase();
    if (!allowedPaymentMethods.contains(method)) {
      throw ArgumentError('Unsupported payment method: $paymentMethodLabel');
    }
    final amountMinor = _moneyToMinor(amount);
    if (amountMinor <= 0) {
      throw ArgumentError('Repayment amount must be greater than 0.');
    }
    final normalizedAmount = _minorToMoney(amountMinor);

    final db = await _appDb.database;
    final existing = await db.query(
      'receivables_local',
      columns: ['id', 'outstanding_amount', 'status'],
      where: 'id = ?',
      whereArgs: [receivableId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw ArgumentError('Debt not found.');
    }
    final currentRow = existing.first;
    final currentStatus = (currentRow['status'] ?? 'open') as String;
    if (currentStatus == 'settled' || currentStatus == 'cancelled') {
      throw ArgumentError('Cannot record repayment on a $currentStatus debt.');
    }
    final outstandingMinor =
        _moneyToMinor((currentRow['outstanding_amount'] ?? '0.00') as String);
    if (amountMinor > outstandingMinor) {
      throw ArgumentError(
        'Repayment exceeds outstanding balance.',
      );
    }

    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final paymentId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final newOutstandingMinor = outstandingMinor - amountMinor;
    final newOutstanding = _minorToMoney(newOutstandingMinor);
    final newStatus = newOutstandingMinor == 0 ? 'settled' : 'partially_paid';

    await db.transaction((tx) async {
      await tx.insert(
        'receivable_payments_local',
        {
          'id': paymentId,
          'receivable_id': receivableId,
          'amount': normalizedAmount,
          'payment_method_label': method,
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'status': 'pending',
          'created_at': now,
        },
      );

      await tx.update(
        'receivables_local',
        {
          'outstanding_amount': newOutstanding,
          'status': newStatus,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [receivableId],
      );

      await _appDb.syncQueue.enqueue(
        entityType: 'receivable_payment',
        operation: 'create',
        entityId: paymentId,
        payloadJson: jsonEncode({
          'payment_id': paymentId,
          'receivable_id': receivableId,
          'amount': normalizedAmount,
          'payment_method_label': method,
        }),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });

    return paymentId;
  }

  /// Updates the payment link cached on a receivable after a successful
  /// `/payments/initiate` call. No sync queue entry — the server already
  /// has the link via the response.
  Future<void> attachPaymentContextLocal({
    required String receivableId,
    required String paymentLink,
    required String paymentId,
    required String paymentAmount,
  }) async {
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'receivables_local',
      {
        'payment_link': paymentLink,
        'payment_id': paymentId,
        'payment_amount': paymentAmount,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [receivableId],
    );
  }

  // -------------------------------------------------------------- sync

  Future<SyncQueueRunSummary> syncPendingQueue({int limit = 100}) {
    return _syncQueueRunner.run(limit: limit);
  }

  // -------------------------------------------------------------- helpers

  int _moneyToMinor(String value) {
    final raw = value.trim();
    final match = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(raw);
    if (match == null) {
      throw ArgumentError('Invalid amount: $value');
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

  String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Aggregate read-state surfaced to the UI controller.
class DebtsViewData {
  const DebtsViewData({
    required this.customers,
    required this.receivables,
  });

  final List<LocalDebtCustomer> customers;
  final List<LocalReceivableRecord> receivables;

  DebtsViewData copyWith({
    List<LocalDebtCustomer>? customers,
    List<LocalReceivableRecord>? receivables,
  }) {
    return DebtsViewData(
      customers: customers ?? this.customers,
      receivables: receivables ?? this.receivables,
    );
  }
}
