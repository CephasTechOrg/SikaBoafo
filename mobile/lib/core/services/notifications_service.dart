import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../app/theme/app_theme.dart';

class NotificationsService {
  NotificationsService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: darwin);
    await _plugin.initialize(settings);
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
    await _plugin.show(2001, title, body, details);
  }

  Future<void> showTestNotification({
    required int id,
    required String title,
    required String body,
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
    await _plugin.show(id, title, body, details);
  }
}

