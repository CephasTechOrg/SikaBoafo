import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/services/notifications_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../settings/providers/notification_prefs_provider.dart';

final debtRemindersProvider = AsyncNotifierProvider.autoDispose
    .family<DebtRemindersController, List<DateTime>, String>(
  DebtRemindersController.new,
);

class DebtRemindersController
    extends AutoDisposeFamilyAsyncNotifier<List<DateTime>, String> {
  static const _kvKey = 'debt_reminders';

  static int _stableId(String receivableId, int index) {
    // Stable, deterministic 31-bit hash.
    var h = 0;
    for (final c in receivableId.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return (h % 100000) * 10 + (index % 10);
  }

  Future<Map<String, List<DateTime>>> _loadAll() async {
    String? raw;
    try {
      raw = await ref.read(appDatabaseProvider).kv.get(_kvKey);
    } catch (_) {
      // Widget tests / unsupported platforms may not have sqflite bindings.
      return {};
    }
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, List<DateTime>>{};
      for (final entry in decoded.entries) {
        final key = entry.key;
        final v = entry.value;
        if (key is! String || v is! List) continue;
        final times = v
            .whereType<String>()
            .map((s) => DateTime.tryParse(s)?.toLocal())
            .whereType<DateTime>()
            .toList();
        times.sort();
        out[key] = times;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAll(Map<String, List<DateTime>> all) async {
    final encoded = <String, List<String>>{};
    for (final e in all.entries) {
      encoded[e.key] =
          e.value.map((d) => d.toUtc().toIso8601String()).toList(growable: false);
    }
    try {
      await ref
          .read(appDatabaseProvider)
          .kv
          .put(_kvKey, jsonEncode(encoded));
    } catch (_) {
      // Widget tests / unsupported platforms may not have sqflite bindings.
    }
  }

  @override
  Future<List<DateTime>> build(String receivableId) async {
    try {
      final all = await _loadAll();
      return all[receivableId] ?? const <DateTime>[];
    } catch (_) {
      // In widget tests (or if the local DB isn't ready), prefer returning an
      // empty list rather than keeping the UI in a perpetual loading state.
      return const <DateTime>[];
    }
  }

  Future<void> addReminder({required DateTime whenLocal}) async {
    final receivableId = arg;
    final current = state.valueOrNull ?? const <DateTime>[];
    final next = [...current, whenLocal]..sort();
    state = AsyncData(next);

    final all = await _loadAll();
    all[receivableId] = next;
    await _saveAll(all);

    await _syncSchedules(receivableId, next);
  }

  Future<void> removeReminderAt(int index) async {
    final receivableId = arg;
    final current = state.valueOrNull ?? const <DateTime>[];
    if (index < 0 || index >= current.length) return;
    final next = [...current]..removeAt(index);
    state = AsyncData(next);

    final all = await _loadAll();
    if (next.isEmpty) {
      all.remove(receivableId);
    } else {
      all[receivableId] = next;
    }
    await _saveAll(all);

    await _syncSchedules(receivableId, next);
  }

  Future<void> _syncSchedules(String receivableId, List<DateTime> times) async {
    final prefs = ref.read(notificationPrefsProvider).valueOrNull;
    if (prefs?.debtRemindersEnabled != true) return;

    const android = AndroidNotificationDetails(
      'debt_reminders',
      'Debt reminders',
      channelDescription: 'Custom reminders you set per debt',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.forest,
    );

    // Cancel all existing for this debt (up to 10 slots).
    final notifications = ref.read(notificationsServiceProvider);
    for (var i = 0; i < 10; i++) {
      await notifications.cancel(_stableId(receivableId, i));
    }

    for (var i = 0; i < times.length && i < 10; i++) {
      final when = times[i];
      if (when.isBefore(DateTime.now())) continue;
      await notifications.scheduleAt(
        id: _stableId(receivableId, i),
        type: AppNotificationType.debtReminder,
        title: 'Debt reminder',
        body: 'Tap to review this debt and record payment.',
        whenLocal: when,
        android: android,
        route: '/debts/$receivableId',
        entityId: receivableId,
      );
    }
  }
}

