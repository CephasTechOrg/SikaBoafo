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
  NotificationsService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<void> Function(ShownNotificationEvent event)? onShown,
    Future<void> Function(AppNotificationPayload payload)? onTapped,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _onShown = onShown,
        _onTapped = onTapped;

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<void> Function(ShownNotificationEvent event)? _onShown;
  final Future<void> Function(AppNotificationPayload payload)? _onTapped;
  bool _tzReady = false;

  int _defaultId() =>
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

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
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
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
    _onTapped?.call(parsed);
    final ctx = rootNavigatorKey.currentContext;
    final router = ctx == null ? null : GoRouter.maybeOf(ctx);
    if (router == null) return;
    router.go(parsed.route);
  }

  Future<void> _recordShown({
    required int notificationId,
    required AppNotificationType type,
    required String title,
    required String body,
    required String route,
    String? entityId,
    required String payloadJson,
  }) async {
    await _onShown?.call(
      ShownNotificationEvent(
        notificationId: notificationId,
        type: type.name,
        title: title,
        body: body,
        route: route,
        entityId: entityId,
        payload: jsonDecode(payloadJson),
      ),
    );
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
    final id = _defaultId();
    await _recordShown(
      notificationId: id,
      type: AppNotificationType.syncStatus,
      title: title,
      body: body,
      route: route,
      payloadJson: payload,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> showNow({
    int? id,
    required AppNotificationType type,
    required String title,
    required String body,
    required AndroidNotificationDetails android,
    String route = '/home',
    String? entityId,
  }) async {
    final notificationId = id ?? _defaultId();
    final payload = jsonEncode(
      AppNotificationPayload(type: type, route: route, entityId: entityId)
          .toJson(),
    );
    await _recordShown(
      notificationId: notificationId,
      type: type,
      title: title,
      body: body,
      route: route,
      entityId: entityId,
      payloadJson: payload,
    );
    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(android: android),
      payload: payload,
    );
  }

  /// Schedules a notification for a future time.
  ///
  /// Note: this does NOT record an inbox entry now — a scheduled notification
  /// hasn't been shown yet. The OS displays it at [whenLocal]; recording it as
  /// "shown" at schedule time wrongly surfaced it in the in-app inbox instantly.
  ///
  /// Exact alarms (`exactAllowWhileIdle`) need the `SCHEDULE_EXACT_ALARM` /
  /// `USE_EXACT_ALARM` permission on Android 12+, which we don't request (and
  /// Play restricts to clock/alarm apps). Without it the plugin throws
  /// `exact_alarms_not_permitted`. So we schedule **inexact** by default
  /// (fine for debt nudges) and fall back to inexact if an exact request is
  /// ever rejected — the call never throws for a permission reason.
  Future<void> scheduleAt({
    required int id,
    required AppNotificationType type,
    required String title,
    required String body,
    required DateTime whenLocal,
    required AndroidNotificationDetails android,
    String route = '/home',
    String? entityId,
    bool exact = false,
  }) async {
    await _initTimezone();
    final payload = jsonEncode(
      AppNotificationPayload(type: type, route: route, entityId: entityId)
          .toJson(),
    );
    final scheduled = tz.TZDateTime.from(whenLocal, tz.local);

    Future<void> schedule(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(android: android),
        payload: payload,
        androidScheduleMode: mode,
      );
    }

    final preferred = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await schedule(preferred);
    } on Exception {
      // Most commonly `exact_alarms_not_permitted`. Retry inexact so the
      // reminder is still scheduled and the caller never sees a false error.
      if (preferred != AndroidScheduleMode.inexactAllowWhileIdle) {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } else {
        rethrow;
      }
    }
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
    await _recordShown(
      notificationId: id,
      type: type,
      title: title,
      body: body,
      route: route,
      entityId: entityId,
      payloadJson: payload,
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
    await _recordShown(
      notificationId: id,
      type: AppNotificationType.test,
      title: title,
      body: body,
      route: route,
      payloadJson: payload,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}

class ShownNotificationEvent {
  const ShownNotificationEvent({
    required this.notificationId,
    required this.type,
    required this.title,
    required this.body,
    required this.route,
    required this.payload,
    this.entityId,
  });

  final int notificationId;
  final String type;
  final String title;
  final String body;
  final String route;
  final String? entityId;
  final Object payload;
}

