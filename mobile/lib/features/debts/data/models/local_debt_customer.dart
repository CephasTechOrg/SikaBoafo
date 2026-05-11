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
