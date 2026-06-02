import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/services/notifications_service.dart';
import '../../../data/local/app_database.dart';
import 'models/local_debt_reminder.dart';

/// CRUD over `local_debt_reminders` plus delegates to [NotificationsService]
/// for plugin-side scheduling / cancellation.
class DebtRemindersRepository {
  DebtRemindersRepository({
    required AppDatabase appDb,
    required NotificationsService notifications,
  })  : _appDb = appDb,
        _notifications = notifications;

  final AppDatabase _appDb;
  final NotificationsService _notifications;
  final _uuid = const Uuid();

  static const _channelId = 'debt_reminders';
  static const _channelName = 'Debt reminders';
  static const _channelDescription =
      'Local reminders for outstanding debts you scheduled.';

  Future<List<LocalDebtReminder>> listForReceivable(String receivableId) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'local_debt_reminders',
      where: 'receivable_id = ?',
      whereArgs: [receivableId],
      orderBy: 'fire_at ASC',
    );
    return rows.map(LocalDebtReminder.fromRow).toList(growable: false);
  }

  Future<LocalDebtReminder> create({
    required String receivableId,
    required String customerName,
    required String amountDisplay,
    required DateTime fireAt,
    String? message,
  }) async {
    final fireAtMillis = fireAt.toLocal().millisecondsSinceEpoch;
    if (fireAtMillis <= DateTime.now().millisecondsSinceEpoch) {
      throw ArgumentError('Reminder time must be in the future.');
    }

    final db = await _appDb.database;
    final reminderId = _uuid.v4();
    final notificationId = _notificationIdFor(fireAtMillis);
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanedMessage = _cleanOptional(message);

    await db.insert('local_debt_reminders', {
      'id': reminderId,
      'receivable_id': receivableId,
      'fire_at': fireAtMillis,
      'message': cleanedMessage,
      'status': 'scheduled',
      'notification_id': notificationId,
      'created_at': now,
    });

    // Best-effort permission request — the plugin no-ops on platforms that
    // don't require one. Failure to schedule should still allow the row to
    // exist (we can re-schedule on next app launch if needed).
    await _notifications.requestPermissionsIfNeeded();
    final body = (cleanedMessage != null && cleanedMessage.isNotEmpty)
        ? cleanedMessage
        : '$customerName still owes $amountDisplay. Tap to follow up.';
    await _notifications.scheduleAt(
      id: notificationId,
      type: AppNotificationType.debtReminder,
      title: 'Debt reminder · $customerName',
      body: body,
      whenLocal: fireAt.toLocal(),
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        color: AppColors.forest,
      ),
      route: '${AppRoute.debts.path}/$receivableId',
      entityId: receivableId,
    );

    return LocalDebtReminder(
      id: reminderId,
      receivableId: receivableId,
      fireAtMillis: fireAtMillis,
      message: cleanedMessage,
      status: 'scheduled',
      notificationId: notificationId,
      createdAtMillis: now,
    );
  }

  /// Cancels the pending OS notification (if any) and removes the row entirely
  /// so cancelled reminders don't linger and clutter the list.
  Future<void> delete({required String reminderId}) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'local_debt_reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final reminder = LocalDebtReminder.fromRow(rows.first);
    await _notifications.cancel(reminder.notificationId);
    await db.delete(
      'local_debt_reminders',
      where: 'id = ?',
      whereArgs: [reminderId],
    );
  }

  /// Marks past-due scheduled reminders as `fired`. Called opportunistically
  /// when the section is rendered so the UI doesn't show stale "scheduled"
  /// rows after the OS has shown the notification.
  Future<void> markPastFired() async {
    final db = await _appDb.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'local_debt_reminders',
      {'status': 'fired'},
      where: 'status = ? AND fire_at <= ?',
      whereArgs: ['scheduled', now],
    );
  }

  static int _notificationIdFor(int fireAtMillis) {
    // 32-bit positive int range required by the plugin. Use the fire-at
    // millis (truncated) — it's unique enough per-debt at second granularity.
    return fireAtMillis.remainder(2147483647).abs();
  }

  static String? _cleanOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Helper used by the schedule sheet to compose default reminder copy
/// without forcing every caller to repeat the same template.
String defaultReminderMessage({
  required String customerName,
  required String amountDisplay,
}) {
  return 'Hi $customerName, just a friendly reminder that $amountDisplay is '
      'still outstanding. Thank you!';
}

/// Convenience for the section header to combine date + time labels.
String reminderFireLabel(DateTime when) {
  final local = when.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year} · $h:$m';
}
