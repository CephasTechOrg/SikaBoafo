import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/services/api_client.dart';
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

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(secureTokenStorageProvider),
    onUnauthorized: () async {
      final context = rootNavigatorKey.currentContext;
      if (context == null) {
        return;
      }
      GoRouter.of(context).go(AppRoute.auth.path);
    },
  );
});
