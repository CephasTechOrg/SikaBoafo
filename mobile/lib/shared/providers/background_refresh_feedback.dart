import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation_keys.dart';

/// Which domain failed to refresh in the background (MOB-03).
enum BackgroundRefreshScope {
  sync,
  debts,
  inventory,
}

extension BackgroundRefreshScopeLabel on BackgroundRefreshScope {
  String get snackbarPrefix => switch (this) {
        BackgroundRefreshScope.sync => 'Sync update failed',
        BackgroundRefreshScope.debts => 'Debts refresh failed',
        BackgroundRefreshScope.inventory => 'Inventory refresh failed',
      };
}

/// Reports background refresh/sync failures and shows a deduped SnackBar via
/// [rootScaffoldMessengerKey]. Manual (user-initiated) refreshes should pass
/// [userInitiated: true] so callers can show their own inline feedback.
class BackgroundRefreshFeedback {
  BackgroundRefreshFeedback();

  String? _lastDedupeKey;
  DateTime? _lastShownAt;
  static const _dedupeWindow = Duration(seconds: 45);

  void reportFailure({
    required BackgroundRefreshScope scope,
    required String message,
    bool userInitiated = false,
  }) {
    if (userInitiated) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final key = '${scope.name}:$trimmed';
    final now = DateTime.now();
    if (_lastDedupeKey == key &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < _dedupeWindow) {
      return;
    }
    _lastDedupeKey = key;
    _lastShownAt = now;

    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${scope.snackbarPrefix}: $trimmed'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

final backgroundRefreshFeedbackProvider =
    Provider<BackgroundRefreshFeedback>((ref) {
  return BackgroundRefreshFeedback();
});
