class LocalReceivableRecord {
  const LocalReceivableRecord({
    required this.receivableId,
    required this.customerId,
    required this.originalAmount,
    required this.outstandingAmount,
    required this.status,
    required this.syncStatus,
    required this.createdAtMillis,
    this.customerName,
    this.dueDateIso,
    this.note,
    this.invoiceNumber,
    this.paymentLink,
    this.paymentId,
    this.paymentAmount,
    this.paymentLinkExpiresAtIso,
    this.providerReference,
    this.saleId,
    this.createdByUserId,
  });

  final String receivableId;
  final String customerId;

  /// Customer name resolved at read time via JOIN — convenience field only.
  final String? customerName;

  final String originalAmount;
  final String outstandingAmount;

  /// 'open' | 'partially_paid' | 'settled' | 'cancelled'.
  final String status;

  final String? dueDateIso;
  final String? note;
  final String? invoiceNumber;
  final String? paymentLink;
  final String? paymentId;
  final String? paymentAmount;

  /// ISO8601 timestamp the active pending payment link expires at, or `null`
  /// when there is no active pending payment (settled / failed / never
  /// initiated). The server is authoritative; UI renders a countdown only.
  final String? paymentLinkExpiresAtIso;
  final String? providerReference;
  final String? saleId;
  final String? createdByUserId;

  /// Sync queue status overlaid via JOIN: 'applied' once server confirmed.
  final String syncStatus;
  final int createdAtMillis;

  bool get isTerminal => status == 'settled' || status == 'cancelled';

  factory LocalReceivableRecord.fromRow(Map<String, Object?> row) {
    return LocalReceivableRecord(
      receivableId: (row['id'] ?? '') as String,
      customerId: (row['customer_id'] ?? '') as String,
      customerName: row['customer_name'] as String?,
      originalAmount: (row['original_amount'] ?? '0.00') as String,
      outstandingAmount: (row['outstanding_amount'] ?? '0.00') as String,
      status: (row['status'] ?? 'open') as String,
      dueDateIso: row['due_date'] as String?,
      note: row['note'] as String?,
      invoiceNumber: row['invoice_number'] as String?,
      paymentLink: row['payment_link'] as String?,
      paymentId: row['payment_id'] as String?,
      paymentAmount: row['payment_amount'] as String?,
      paymentLinkExpiresAtIso: row['payment_link_expires_at'] as String?,
      providerReference: row['payment_provider_reference'] as String?,
      saleId: row['sale_id'] as String?,
      createdByUserId: row['created_by_user_id'] as String?,
      syncStatus: (row['sync_status'] ?? 'applied') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}
