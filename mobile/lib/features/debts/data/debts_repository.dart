import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/sync/sync_queue_runner.dart';

class LocalDebtCustomer {
  const LocalDebtCustomer({
    required this.customerId,
    required this.name,
    this.phoneNumber,
    this.whatsappNumber,
    this.email,
    this.notes,
    this.totalOutstanding = '0.00',
  });

  final String customerId;
  final String name;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? email;
  final String? notes;
  final String totalOutstanding;

  factory LocalDebtCustomer.fromRow(Map<String, Object?> row) {
    return LocalDebtCustomer(
      customerId: (row['id'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      phoneNumber: row['phone_number'] as String?,
      whatsappNumber: row['whatsapp_number'] as String?,
      email: row['email'] as String?,
      notes: row['notes'] as String?,
      totalOutstanding: (row['total_outstanding'] ?? '0.00') as String,
    );
  }
}

class LocalReceivableRecord {
  const LocalReceivableRecord({
    required this.receivableId,
    required this.customerId,
    required this.customerName,
    required this.originalAmount,
    required this.outstandingAmount,
    required this.status,
    required this.syncStatus,
    required this.createdAtMillis,
    this.dueDateIso,
    this.note,
    this.invoiceNumber,
    this.paymentLink,
  });

  final String receivableId;
  final String customerId;
  final String customerName;
  final String originalAmount;
  final String outstandingAmount;
  final String status;
  final String syncStatus;
  final int createdAtMillis;
  final String? dueDateIso;
  final String? note;
  final String? invoiceNumber;
  final String? paymentLink;

  factory LocalReceivableRecord.fromRow(Map<String, Object?> row) {
    return LocalReceivableRecord(
      receivableId: (row['id'] ?? '') as String,
      customerId: (row['customer_id'] ?? '') as String,
      customerName: (row['customer_name'] ?? 'Unknown Customer') as String,
      originalAmount: (row['original_amount'] ?? '0.00') as String,
      outstandingAmount: (row['outstanding_amount'] ?? '0.00') as String,
      status: (row['status'] ?? 'open') as String,
      syncStatus: (row['sync_status'] ?? 'pending') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
      dueDateIso: row['due_date'] as String?,
      note: row['note'] as String?,
      invoiceNumber: row['invoice_number'] as String?,
      paymentLink: row['payment_link'] as String?,
    );
  }
}

class LocalReceivablePaymentRecord {
  const LocalReceivablePaymentRecord({
    required this.paymentId,
    required this.amount,
    required this.paymentMethodLabel,
    required this.syncStatus,
    required this.createdAtMillis,
  });

  final String paymentId;
  final String amount;
  final String paymentMethodLabel;
  final String syncStatus;
  final int createdAtMillis;

  factory LocalReceivablePaymentRecord.fromRow(Map<String, Object?> row) {
    return LocalReceivablePaymentRecord(
      paymentId: (row['id'] ?? '') as String,
      amount: (row['amount'] ?? '0.00') as String,
      paymentMethodLabel: (row['payment_method_label'] ?? 'cash') as String,
      syncStatus: (row['sync_status'] ?? 'pending') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}

class LocalReceivableDetail {
  const LocalReceivableDetail({
    required this.record,
    required this.payments,
    this.customerPhoneNumber,
  });

  final LocalReceivableRecord record;
  final List<LocalReceivablePaymentRecord> payments;
  final String? customerPhoneNumber;

  int get paymentCount => payments.length;
}

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

  Future<List<LocalDebtCustomer>> listCustomers() async {
    final db = await _appDb.database;
    final rows = await db.query(
      'customers_local',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(LocalDebtCustomer.fromRow).toList(growable: false);
  }

  Future<List<LocalDebtCustomer>> listCustomersWithBalance() async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
SELECT c.id, c.name, c.phone_number, c.whatsapp_number, c.email, c.notes,
       COALESCE(
         (SELECT SUM(CAST(r.outstanding_amount AS REAL))
          FROM receivables_local r
          WHERE r.customer_id = c.id),
         0.0
       ) AS total_outstanding_real
FROM customers_local c
ORDER BY c.name COLLATE NOCASE ASC
''');
    return rows.map((row) {
      final raw = (row['total_outstanding_real'] as num? ?? 0.0).toDouble();
      final major = raw.truncate();
      final minor = ((raw - major) * 100).round().toString().padLeft(2, '0');
      return LocalDebtCustomer(
        customerId: (row['id'] ?? '') as String,
        name: (row['name'] ?? '') as String,
        phoneNumber: row['phone_number'] as String?,
        whatsappNumber: row['whatsapp_number'] as String?,
        email: row['email'] as String?,
        notes: row['notes'] as String?,
        totalOutstanding: '$major.$minor',
      );
    }).toList(growable: false);
  }

  Future<LocalDebtCustomer?> getCustomerById(String id) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery('''
SELECT c.id, c.name, c.phone_number, c.whatsapp_number, c.email, c.notes,
       COALESCE(
         (SELECT SUM(CAST(r.outstanding_amount AS REAL))
          FROM receivables_local r
          WHERE r.customer_id = c.id),
         0.0
       ) AS total_outstanding_real
FROM customers_local c
WHERE c.id = ?
LIMIT 1
''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final raw = (row['total_outstanding_real'] as num? ?? 0.0).toDouble();
    final major = raw.truncate();
    final minor = ((raw - major) * 100).round().toString().padLeft(2, '0');
    return LocalDebtCustomer(
      customerId: (row['id'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      phoneNumber: row['phone_number'] as String?,
      whatsappNumber: row['whatsapp_number'] as String?,
      email: row['email'] as String?,
      notes: row['notes'] as String?,
      totalOutstanding: '$major.$minor',
    );
  }

  Future<List<LocalReceivableRecord>> listReceivablesForCustomer(
    String customerId, {
    int limit = 100,
  }) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT r.id, r.customer_id, c.name AS customer_name,
       r.original_amount, r.outstanding_amount, r.due_date,
       r.status, r.invoice_number, r.payment_link, r.created_at,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status = 'failed'
         ) THEN 'failed'
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status IN ('pending', 'sending')
         ) THEN 'pending'
         ELSE 'applied'
       END AS sync_status
FROM receivables_local r
JOIN customers_local c ON c.id = r.customer_id
WHERE r.customer_id = ?
ORDER BY r.created_at DESC
LIMIT ?
''',
      [customerId, limit],
    );
    return rows.map(LocalReceivableRecord.fromRow).toList(growable: false);
  }

  Future<List<LocalReceivableRecord>> listReceivables({int limit = 100}) async {
    final db = await _appDb.database;
    final rows = await db.rawQuery(
      '''
SELECT r.id, r.customer_id, c.name AS customer_name,
       r.original_amount, r.outstanding_amount, r.due_date,
       r.status, r.invoice_number, r.payment_link, r.created_at,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status = 'failed'
         ) THEN 'failed'
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status IN ('pending', 'sending')
         ) THEN 'pending'
         ELSE 'applied'
       END AS sync_status
FROM receivables_local r
JOIN customers_local c ON c.id = r.customer_id
ORDER BY r.created_at DESC
LIMIT ?
''',
      [limit],
    );
    return rows.map(LocalReceivableRecord.fromRow).toList(growable: false);
  }

  Future<LocalReceivableDetail?> getReceivableDetail(String receivableId) async {
    final db = await _appDb.database;
    final detailRows = await db.rawQuery(
      '''
SELECT r.id, r.customer_id, c.name AS customer_name, c.phone_number,
       r.original_amount, r.outstanding_amount, r.due_date,
       r.status, r.invoice_number, r.payment_link, r.created_at,
       CASE
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status = 'failed'
         ) THEN 'failed'
         WHEN EXISTS (
           SELECT 1 FROM sync_queue q
           WHERE q.entity_id = r.id AND q.status IN ('pending', 'sending')
         ) THEN 'pending'
         ELSE 'applied'
       END AS sync_status
FROM receivables_local r
JOIN customers_local c ON c.id = r.customer_id
WHERE r.id = ?
LIMIT 1
''',
      [receivableId],
    );
    if (detailRows.isEmpty) {
      return null;
    }

    final paymentRows = await db.rawQuery(
      '''
SELECT p.id, p.amount, p.payment_method_label, p.created_at,
       COALESCE(q.status, p.status, 'pending') AS sync_status
FROM receivable_payments_local p
LEFT JOIN sync_queue q
  ON q.local_operation_id = p.local_operation_id
 AND q.source_device_id = p.source_device_id
WHERE p.receivable_id = ?
ORDER BY p.created_at DESC
''',
      [receivableId],
    );

    return LocalReceivableDetail(
      record: LocalReceivableRecord.fromRow(detailRows.first),
      customerPhoneNumber: detailRows.first['phone_number'] as String?,
      payments: paymentRows
          .map(LocalReceivablePaymentRecord.fromRow)
          .toList(growable: false),
    );
  }

  Future<void> createCustomerLocal({
    required String name,
    String? phoneNumber,
  }) async {
    final cleanName = name.trim();
    if (cleanName.length < 2) {
      throw ArgumentError('Customer name must be at least 2 characters.');
    }
    final cleanPhone = _cleanOptional(phoneNumber);
    if (cleanPhone != null && cleanPhone.length < 8) {
      throw ArgumentError('Customer phone number is too short.');
    }

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final customerId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      await tx.insert(
        'customers_local',
        {
          'id': customerId,
          'name': cleanName,
          'phone_number': cleanPhone,
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
            'name': cleanName,
            'phone_number': cleanPhone,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<String> getPaidThisMonth() async {
    final db = await _appDb.database;
    final monthStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
    ).millisecondsSinceEpoch;
    final rows = await db.query(
      'receivable_payments_local',
      columns: ['amount'],
      where: 'created_at >= ?',
      whereArgs: [monthStart],
    );
    int totalMinor = 0;
    for (final row in rows) {
      totalMinor += _moneyToMinor((row['amount'] ?? '0.00') as String);
    }
    return _minorToMoney(totalMinor);
  }

  Future<void> createReceivableLocal({
    required String customerId,
    required String originalAmount,
    String? dueDateIso,
    String? note,
  }) async {
    final amountMinor = _moneyToMinor(originalAmount);
    if (amountMinor <= 0) {
      throw ArgumentError('Debt amount must be greater than 0.');
    }
    final normalizedDueDate = _normalizeDueDate(dueDateIso);

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final receivableId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final amount = _minorToMoney(amountMinor);

    await db.transaction((tx) async {
      final customerRows = await tx.query(
        'customers_local',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [customerId],
        limit: 1,
      );
      if (customerRows.isEmpty) {
        throw ArgumentError('Customer not found.');
      }

      await tx.insert(
        'receivables_local',
        {
          'id': receivableId,
          'customer_id': customerId,
          'original_amount': amount,
          'outstanding_amount': amount,
          'due_date': normalizedDueDate,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          'status': 'open',
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
            'original_amount': amount,
            'due_date': normalizedDueDate,
          }..removeWhere((_, value) => value == null),
        ),
        sourceDeviceId: sourceDeviceId,
        localOperationId: localOpId,
        executor: tx,
      );
    });
  }

  Future<void> recordRepaymentLocal({
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

    final db = await _appDb.database;
    final sourceDeviceId = await _appDb.getOrCreateDeviceId();
    final paymentId = _uuid.v4();
    final localOpId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((tx) async {
      final receivableRows = await tx.query(
        'receivables_local',
        columns: ['id', 'outstanding_amount'],
        where: 'id = ?',
        whereArgs: [receivableId],
        limit: 1,
      );
      if (receivableRows.isEmpty) {
        throw ArgumentError('Receivable not found.');
      }
      final currentOutstanding = _moneyToMinor(
        (receivableRows.first['outstanding_amount'] ?? '0.00') as String,
      );
      if (amountMinor > currentOutstanding) {
        throw ArgumentError(
          'Repayment exceeds outstanding balance. '
          'Outstanding: ${_minorToMoney(currentOutstanding)}.',
        );
      }
      final nextOutstanding = currentOutstanding - amountMinor;
      final nextStatus = nextOutstanding == 0 ? 'settled' : 'partially_paid';

      await tx.update(
        'receivables_local',
        {
          'outstanding_amount': _minorToMoney(nextOutstanding),
          'status': nextStatus,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [receivableId],
      );
      await tx.insert(
        'receivable_payments_local',
        {
          'id': paymentId,
          'receivable_id': receivableId,
          'amount': _minorToMoney(amountMinor),
          'payment_method_label': method,
          'local_operation_id': localOpId,
          'source_device_id': sourceDeviceId,
          'status': 'pending',
          'created_at': now,
        },
      );
      await _appDb.syncQueue.enqueue(
        entityType: 'receivable_payment',
        operation: 'create',
        entityId: receivableId,
        payloadJson: jsonEncode(
          {
            'payment_id': paymentId,
            'receivable_id': receivableId,
            'amount': _minorToMoney(amountMinor),
            'payment_method_label': method,
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

  String? _normalizeDueDate(String? value) {
    final raw = _cleanOptional(value);
    if (raw == null) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw ArgumentError('Due date must be YYYY-MM-DD.');
    }
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }

  String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
