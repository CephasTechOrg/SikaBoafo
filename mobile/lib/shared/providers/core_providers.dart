import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/navigation_keys.dart';
import '../../app/router.dart';
import '../../core/services/api_client.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/notifications_service.dart';
import '../../core/services/session_service.dart';
import '../../core/services/secure_token_storage.dart';
import '../../data/local/app_database.dart';
import '../../features/notifications/providers/notifications_inbox_providers.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  return NotificationsService(
    onShown: (event) async {
      await ref.read(notificationsInboxControllerProvider.notifier).record(
            notificationId: event.notificationId,
            type: event.type,
            title: event.title,
            body: event.body,
            route: event.route,
            entityId: event.entityId,
            payload: event.payload,
          );
    },
    onTapped: (payload) async {
      // Best-effort: update unread badge when user taps from system tray.
      // Inbox row matching by route/entity can be done later if needed.
      ref.invalidate(unreadNotificationsCountProvider);
    },
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final sessionServiceProvider = Provider<SessionService>((ref) {
  return SessionService(
    appDb: ref.watch(appDatabaseProvider),
    tokenStorage: ref.watch(secureTokenStorageProvider),
    serverLogout: () async {
      final dio = ref.read(apiClientProvider).dio;
      await dio.post<dynamic>('/auth/logout');
    },
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(secureTokenStorageProvider),
    onUnauthorized: () async {
      final context = rootNavigatorKey.currentContext;
      final router = context == null ? null : GoRouter.maybeOf(context);
      final messenger = rootScaffoldMessengerKey.currentState;
      // The token is already invalid here, so skip the server logout call and
      // just clear local state. (Avoids a provider dependency cycle with
      // sessionServiceProvider.)
      await ref.read(secureTokenStorageProvider).clearSession();
      await ref.read(appDatabaseProvider).clearBusinessData();
      if (router == null) {
        return;
      }
      router.go(AppRoute.auth.path);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please sign in again.'),
          ),
        );
    },
  );
});
