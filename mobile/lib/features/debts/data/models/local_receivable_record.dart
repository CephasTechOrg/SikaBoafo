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
