import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import '../../app/navigation_keys.dart';
import '../../app/theme/app_theme.dart';

enum AppNotificationType {
  syncStatus,
  debtReminder,
  lowStock,
  paystack,
  dailySummary,
  test,
}

class AppNotificationPayload {
  const AppNotificationPayload({
    required this.type,
    required this.route,
    this.entityId,
  });

  final AppNotificationType type;
  final String route;
  final String? entityId;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'route': route,
        if (entityId != null) 'entityId': entityId,
      };

  static AppNotificationPayload? tryParse(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty) return null;
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map) return null;
      final typeRaw = decoded['type'];
      final route = decoded['route'];
      if (typeRaw is! String || route is! String) return null;
      final type = AppNotificationType.values
          .cast<AppNotificationType?>()
          .firstWhere((t) => t?.name == typeRaw, orElse: () => null);
      if (type == null) return null;
      final entityId = decoded['entityId'];
      return AppNotificationPayload(
        type: type,
        route: route,
        entityId: entityId is String ? entityId : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class NotificationsService {
  NotificationsService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _tzReady = false;

  Future<void> init() async {
    await _initTimezone();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) =>
          _handleTap(payload: resp.payload),
      onDidReceiveBackgroundNotificationResponse: _backgroundTapHandler,
    );
  }

  Future<void> _initTimezone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Fallback: leave default (UTC) if timezone couldn't be resolved.
    }
    _tzReady = true;
  }

  @pragma('vm:entry-point')
  static void _backgroundTapHandler(NotificationResponse response) {
    // Best-effort: app may not have a navigator yet. We still keep this handler
    // registered so taps are delivered when possible.
  }

  void _handleTap({required String? payload}) {
    final parsed = AppNotificationPayload.tryParse(payload);
    if (parsed == null) return;
    final ctx = rootNavigatorKey.currentContext;
    final router = ctx == null ? null : GoRouter.maybeOf(ctx);
    if (router == null) return;
    router.go(parsed.route);
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ runtime permission (older versions return null/true).
      final ok = await android?.requestNotificationsPermission();
      return ok ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final ok = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return ok ?? true;
    }
    return true;
  }

  Future<void> showSyncStatusNotification({
    required String title,
    required String body,
    String route = '/home',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sync_status',
      'Sync status',
      channelDescription: 'Shows offline/sync status updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      color: AppColors.forest,
    );
    const details = NotificationDetails(android: androidDetails);
    final payload = jsonEncode(
      AppNotificationPayload(type: AppNotificationType.syncStatus, route: route)
          .toJson(),
    );
    await _plugin.show(2001, title, body, details, payload: payload);
  }

  Future<void> showNow({
    required int id,
    required AppNotificationType type,
    required String title,
    required String body,
    required AndroidNotificationDetails android,
    String route = '/home',
    String? entityId,
  }) async {
    final payload = jsonEncode(
      AppNotificationPayload(type: type, route: route, entityId: entityId)
          .toJson(),
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: android),
      payload: payload,
    );
  }

  Future<void> scheduleAt({
    required int id,
    required AppNotificationType type,
    required String title,
    required String body,
    required DateTime whenLocal,
    required AndroidNotificationDetails android,
    String route = '/home',
    String? entityId,
    bool exact = true,
  }) async {
    await _initTimezone();
    final payload = jsonEncode(
      AppNotificationPayload(type: type, route: route, entityId: entityId)
          .toJson(),
    );
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(android: android),
      payload: payload,
      androidScheduleMode:
          exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexact,
    );
  }

  Future<void> scheduleDailyAtTime({
    required int id,
    required AppNotificationType type,
    required String title,
    required String body,
    required TimeOfDay timeLocal,
    required AndroidNotificationDetails android,
    String route = '/home',
    String? entityId,
  }) async {
    await _initTimezone();
    final payload = jsonEncode(
      AppNotificationPayload(type: type, route: route, entityId: entityId)
          .toJson(),
    );
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      timeLocal.hour,
      timeLocal.minute,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      NotificationDetails(android: android),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<void> showTestNotification({
    required int id,
    required String title,
    required String body,
    String route = '/home',
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'test_events',
      'Test events',
      channelDescription: 'Test notifications (sales, low stock, payments)',
      importance: Importance.high,
      priority: Priority.high,
      color: AppColors.forest,
    );
    const details = NotificationDetails(android: androidDetails);
    final payload = jsonEncode(
      AppNotificationPayload(type: AppNotificationType.test, route: route)
          .toJson(),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}

