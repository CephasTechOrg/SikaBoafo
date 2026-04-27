import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';

/// Keeps the biometric preference in memory, synced with secure storage.
final biometricPrefProvider =
    AsyncNotifierProvider<BiometricPrefController, bool>(BiometricPrefController.new);

class BiometricPrefController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final storage = ref.watch(secureTokenStorageProvider);
    return storage.isBiometricEnabled();
  }

  Future<bool> setEnabled(bool enabled) async {
    state = const AsyncLoading<bool>().copyWithPrevious(state);
    final storage = ref.read(secureTokenStorageProvider);

    await storage.setBiometricEnabled(enabled);

    // Read-after-write to ensure persistence. If it fails, at least keep UI
    // consistent with the user's last choice.
    final persisted = await storage.isBiometricEnabled();
    state = AsyncData(persisted);
    return persisted;
  }
}

