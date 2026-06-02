class LocalDebtCustomer {
  const LocalDebtCustomer({
    required this.customerId,
    required this.name,
    required this.totalOutstanding,
    required this.syncStatus,
    required this.createdAtMillis,
    this.phoneNumber,
    this.whatsappNumber,
    this.email,
    this.notes,
    this.lastActivityAtMillis,
    this.totalPurchasesFormatted,
  });

  final String customerId;
  final String name;
  final String? phoneNumber;
  final String? whatsappNumber;
  final String? email;
  final String? notes;

  /// Sum of outstanding amounts on this customer's receivables, formatted "0.00".
  final String totalOutstanding;

  /// Most recent receivable created_at (epoch ms), falls back to customer created_at.
  final int? lastActivityAtMillis;

  /// Sum of original_amount across all receivables, formatted "0.00".
  final String? totalPurchasesFormatted;

  /// 'pending' (local-only), 'sending', 'applied', 'failed', 'conflict', 'dead'.
  final String syncStatus;
  final int createdAtMillis;

  factory LocalDebtCustomer.fromRow(
    Map<String, Object?> row, {
    required String totalOutstanding,
  }) {
    return LocalDebtCustomer(
      customerId: (row['id'] ?? '') as String,
      name: (row['name'] ?? '') as String,
      phoneNumber: row['phone_number'] as String?,
      whatsappNumber: row['whatsapp_number'] as String?,
      email: row['email'] as String?,
      notes: row['notes'] as String?,
      totalOutstanding: totalOutstanding,
      syncStatus: (row['sync_status'] ?? row['status'] ?? 'pending') as String,
      createdAtMillis: (row['created_at'] as int? ?? 0),
      lastActivityAtMillis: row['last_activity_at'] as int?,
      totalPurchasesFormatted: row['total_purchases'] as String?,
    );
  }
}
