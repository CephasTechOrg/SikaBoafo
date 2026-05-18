import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

const merchantOwnerRole = 'merchant_owner';

/// True when the signed-in user may manage staff (owners only).
bool isMerchantOwnerRole(String? role) {
  final normalized = role?.trim();
  if (normalized == null || normalized.isEmpty) {
    // Legacy sessions before role was persisted locally.
    return true;
  }
  return normalized == merchantOwnerRole;
}

final activeUserRoleProvider = FutureProvider<String?>((ref) {
  return ref.watch(appDatabaseProvider).getActiveUserRole();
});

final isMerchantOwnerProvider = FutureProvider<bool>((ref) async {
  final role = await ref.watch(activeUserRoleProvider.future);
  return isMerchantOwnerRole(role);
});
