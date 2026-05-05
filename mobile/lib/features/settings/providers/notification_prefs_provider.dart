import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../app/router.dart';
import '../../../core/services/notifications_service.dart';
import '../../../data/local/kv_cache_repository.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../app/theme/app_theme.dart';

class NotificationPrefs {
  const NotificationPrefs({
    required this.syncStatusEnabled,
    required this.debtRemindersEnabled,
    required this.lowStockEnabled,
    required this.paymentEventsEnabled,
    required this.dailySummaryEnabled,
    required this.dailySummaryTime,
  });

  final bool syncStatusEnabled;
  final bool debtRemindersEnabled;
  final bool lowStockEnabled;
  final bool paymentEventsEnabled;
  final bool dailySummaryEnabled;
  final TimeOfDay dailySummaryTime;

  NotificationPrefs copyWith({
    bool? syncStatusEnabled,
    bool? debtRemindersEnabled,
    bool? lowStockEnabled,
    bool? paymentEventsEnabled,
    bool? dailySummaryEnabled,
    TimeOfDay? dailySummaryTime,
  }) {
    return NotificationPrefs(
      syncStatusEnabled: syncStatusEnabled ?? this.syncStatusEnabled,
      debtRemindersEnabled: debtRemindersEnabled ?? this.debtRemindersEnabled,
      lowStockEnabled: lowStockEnabled ?? this.lowStockEnabled,
      paymentEventsEnabled: paymentEventsEnabled ?? this.paymentEventsEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      dailySummaryTime: dailySummaryTime ?? this.dailySummaryTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'syncStatusEnabled': syncStatusEnabled,
        'debtRemindersEnabled': debtRemindersEnabled,
        'lowStockEnabled': lowStockEnabled,
        'paymentEventsEnabled': paymentEventsEnabled,
        'dailySummaryEnabled': dailySummaryEnabled,
        'dailySummaryTime': _timeToString(dailySummaryTime),
      };

  static NotificationPrefs defaults() => const NotificationPrefs(
        syncStatusEnabled: true,
        debtRemindersEnabled: true,
        lowStockEnabled: true,
        paymentEventsEnabled: true,
        dailySummaryEnabled: true,
        dailySummaryTime: TimeOfDay(hour: 20, minute: 0),
      );

  static NotificationPrefs fromJson(Map<String, dynamic> json) {
    final timeRaw = json['dailySummaryTime'];
    final parsedTime = timeRaw is String ? _tryParseTime(timeRaw) : null;
    return NotificationPrefs(
      syncStatusEnabled: json['syncStatusEnabled'] == true,
      debtRemindersEnabled: json['debtRemindersEnabled'] == true,
      lowStockEnabled: json['lowStockEnabled'] == true,
      paymentEventsEnabled: json['paymentEventsEnabled'] == true,
      dailySummaryEnabled: json['dailySummaryEnabled'] == true,
      dailySummaryTime: parsedTime ?? defaults().dailySummaryTime,
    );
  }

  static TimeOfDay? _tryParseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _timeToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

final notificationPrefsProvider =
    AsyncNotifierProvider<NotificationPrefsController, NotificationPrefs>(
  NotificationPrefsController.new,
);

class NotificationPrefsController extends AsyncNotifier<NotificationPrefs> {
  static const _kvKey = 'notification_prefs';
  static const _dailySummaryNotificationId = 4001;

  Future<KvCacheRepository> _kv() async {
    return KvCacheRepository(ref.read(appDatabaseProvider));
  }

  @override
  Future<NotificationPrefs> build() async {
    final kv = await _kv();
    final raw = await kv.get(_kvKey);
    if (raw == null) return NotificationPrefs.defaults();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return NotificationPrefs.defaults();
      return NotificationPrefs.fromJson(decoded);
    } catch (_) {
      return NotificationPrefs.defaults();
    }
  }

  Future<NotificationPrefs> _persist(NotificationPrefs next) async {
    state = const AsyncLoading<NotificationPrefs>().copyWithPrevious(state);
    final kv = await _kv();
    await kv.put(_kvKey, jsonEncode(next.toJson()));
    state = AsyncData(next);
    await _syncSchedules(next);
    return next;
  }

  Future<void> _syncSchedules(NotificationPrefs prefs) async {
    final notifications = ref.read(notificationsServiceProvider);
    const dailyAndroid = AndroidNotificationDetails(
      'daily_summary',
      'Daily summary',
      channelDescription: 'Daily sales and activity summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: AppColors.forest,
    );

    if (prefs.dailySummaryEnabled) {
      await notifications.scheduleDailyAtTime(
        id: _dailySummaryNotificationId,
        type: AppNotificationType.dailySummary,
        title: 'Daily summary',
        body: 'Tap to see today’s sales and activity.',
        timeLocal: prefs.dailySummaryTime,
        android: dailyAndroid,
        route: AppRoute.reports.path,
      );
    } else {
      await notifications.cancel(_dailySummaryNotificationId);
    }
  }

  Future<NotificationPrefs> setSyncStatusEnabled(bool enabled) =>
      _persist(state.valueOrNull?.copyWith(syncStatusEnabled: enabled) ??
          NotificationPrefs.defaults().copyWith(syncStatusEnabled: enabled));

  Future<NotificationPrefs> setDebtRemindersEnabled(bool enabled) =>
      _persist(state.valueOrNull?.copyWith(debtRemindersEnabled: enabled) ??
          NotificationPrefs.defaults().copyWith(debtRemindersEnabled: enabled));

  Future<NotificationPrefs> setLowStockEnabled(bool enabled) =>
      _persist(state.valueOrNull?.copyWith(lowStockEnabled: enabled) ??
          NotificationPrefs.defaults().copyWith(lowStockEnabled: enabled));

  Future<NotificationPrefs> setPaymentEventsEnabled(bool enabled) =>
      _persist(state.valueOrNull?.copyWith(paymentEventsEnabled: enabled) ??
          NotificationPrefs.defaults().copyWith(paymentEventsEnabled: enabled));

  Future<NotificationPrefs> setDailySummaryEnabled(bool enabled) =>
      _persist(state.valueOrNull?.copyWith(dailySummaryEnabled: enabled) ??
          NotificationPrefs.defaults().copyWith(dailySummaryEnabled: enabled));

  Future<NotificationPrefs> setDailySummaryTime(TimeOfDay time) =>
      _persist(state.valueOrNull?.copyWith(dailySummaryTime: time) ??
          NotificationPrefs.defaults().copyWith(dailySummaryTime: time));
}

