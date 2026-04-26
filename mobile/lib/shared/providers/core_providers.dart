import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/services/api_client.dart';
import '../../core/services/session_service.dart';
import '../../core/services/secure_token_storage.dart';
import '../../data/local/app_database.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
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
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(secureTokenStorageProvider),
    onUnauthorized: () async {
      final context = rootNavigatorKey.currentContext;
      final router = context == null ? null : GoRouter.maybeOf(context);
      final messenger = rootScaffoldMessengerKey.currentState;
      await ref.read(sessionServiceProvider).signOut();
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
