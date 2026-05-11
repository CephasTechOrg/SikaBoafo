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
