class LocalDebtReminder {
  const LocalDebtReminder({
    required this.id,
    required this.receivableId,
    required this.fireAtMillis,
    required this.status,
    required this.notificationId,
    required this.createdAtMillis,
    this.message,
  });

  final String id;
  final String receivableId;
  final int fireAtMillis;
  final String? message;

  /// 'scheduled' | 'fired' | 'cancelled'.
  final String status;

  /// Plugin-side id used by `flutter_local_notifications` so we can cancel.
  final int notificationId;

  final int createdAtMillis;

  DateTime get fireAt =>
      DateTime.fromMillisecondsSinceEpoch(fireAtMillis).toLocal();

  bool get isPast => DateTime.now().millisecondsSinceEpoch >= fireAtMillis;
  bool get isActive => status == 'scheduled' && !isPast;

  factory LocalDebtReminder.fromRow(Map<String, Object?> row) {
    return LocalDebtReminder(
      id: (row['id'] ?? '') as String,
      receivableId: (row['receivable_id'] ?? '') as String,
      fireAtMillis: (row['fire_at'] as int? ?? 0),
      message: row['message'] as String?,
      status: (row['status'] ?? 'scheduled') as String,
      notificationId: (row['notification_id'] as int? ?? 0),
      createdAtMillis: (row['created_at'] as int? ?? 0),
    );
  }
}
