class LocalReceivablePaymentRecord {
  const LocalReceivablePaymentRecord({
    required this.paymentId,
    required this.receivableId,
    required this.amount,
    required this.paymentMethodLabel,
    required this.syncStatus,
    required this.createdAtMillis,
  });

  final String paymentId;
  final String receivableId;
  final String amount;

  /// 'cash' | 'mobile_money' | 'bank_transfer'.
  final String paymentMethodLabel;

  final String syncStatus;
  final int createdAtMillis;

  factory LocalReceivablePaymentRecord.fromRow(Map<String, Object?> row) {
    return LocalReceivablePaymentRecord(
      paymentId: (row['id'] ?? '') as String,
      receivableId: (row['receivable_id'] ?? '') as String,
      amount: (row['amount'] ?? '0.00') as String,
      paymentMethodLabel:
          (row['payment_method_label'] ?? 'cash') as String,
      syncStatus: (row['sync_status'] ?? row['status'] ?? 'pending') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}
