import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/api_client.dart';
import '../../data/local/app_database.dart';
import '../../data/local/sync_queue_repository.dart';
import '../../data/remote/sync_api.dart';
import '../../data/sync/sync_queue_runner.dart';
import '../../data/sync/sync_refresh_service.dart';
import '../../features/debts/data/debts_api.dart';
import '../../features/debts/data/debts_payments_api.dart';
import '../../features/inventory/data/inventory_api.dart';
import '../utils/user_friendly_error.dart';
import 'core_providers.dart';
import '../../features/settings/providers/notification_prefs_provider.dart';

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.backendReachable,
    required this.isSyncing,
    required this.stats,
    required this.failedEntries,
    required this.conflictEntries,
    required this.deadEntries,
    this.lastError,
    this.lastSyncedAt,
  });

  final bool backendReachable;
  final bool isSyncing;
  final SyncQueueStats stats;
  final List<SyncQueueEntry> failedEntries;
  final List<SyncQueueEntry> conflictEntries;
  final List<SyncQueueEntry> deadEntries;
  final String? lastError;
  final DateTime? lastSyncedAt;

  bool get hasFailures => stats.failedCount > 0;
  bool get hasConflicts => stats.conflictCount > 0;
  bool get hasPendingWork => stats.pendingCount > 0 || stats.sendingCount > 0;
}

final syncApiProvider = Provider<SyncApi>((ref) {
  return SyncApi(ref.watch(apiClientProvider));
});

final inventoryApiProvider = Provider<InventoryApi>((ref) {
  return InventoryApi(ref.watch(apiClientProvider));
});

final debtsApiProvider = Provider<DebtsApi>((ref) {
  return DebtsApi(ref.watch(apiClientProvider));
});

final debtsPaymentsApiProvider = Provider<DebtsPaymentsApi>((ref) {
  return DebtsPaymentsApi(ref.watch(apiClientProvider));
});

final syncRefreshServiceProvider = Provider<SyncRefreshService>((ref) {
  return SyncRefreshService(
    appDb: ref.watch(appDatabaseProvider),
    inventoryApi: ref.watch(inventoryApiProvider),
    debtsApi: ref.watch(debtsApiProvider),
  );
});

final syncQueueRunnerProvider = Provider<SyncQueueRunner>((ref) {
  return SyncQueueRunner(
    appDb: ref.watch(appDatabaseProvider),
    syncApi: ref.watch(syncApiProvider),
    refreshService: ref.watch(syncRefreshServiceProvider),
  );
});

// NOT autoDispose: the sync controller is a global background service.
// Making it autoDispose means it rebuilds (and re-pings) on every tab switch,
// causing a false 'Offline' flash while the fresh ping is in-flight.
final syncStatusControllerProvider =
    AsyncNotifierProvider<SyncStatusController, SyncStatusSnapshot>(
  SyncStatusController.new,
);

class SyncStatusController
    extends AsyncNotifier<SyncStatusSnapshot> {
  static const _minInterval = Duration(seconds: 20);
  static const _maxInterval = Duration(minutes: 5);

  AppDatabase get _appDb => ref.read(appDatabaseProvider);
  ApiClient get _apiClient => ref.read(apiClientProvider);
  SyncQueueRunner get _runner => ref.read(syncQueueRunnerProvider);

  Timer? _pollTimer;
  bool _busy = false;
  int _consecutiveFailures = 0;
  String? _lastError;
  DateTime? _lastSyncedAt;
  bool? _lastBackendReachable;
  // Tracks the last confirmed reachability result across rebuilds so the
  // UI never defaults to 'Offline' before the first ping has returned.
  bool? _lastKnownReachable;
  int _lastPendingCount = 0;
  int _lastFailedCount = 0;
  // How many consecutive pings have returned unreachable. The offline
  // notification is only fired after 2 consecutive failures (~40 s) to avoid
  // alerting on transient blips (e.g. brief Wi-Fi hand-off).
  int _consecutiveOfflinePings = 0;

  @override
  Future<SyncStatusSnapshot> build() async {
    _scheduleNextPoll();
    ref.onDispose(() => _pollTimer?.cancel());
    unawaited(_maybePruneApplied());
    return _refreshInternal(attemptSync: true);
  }

  Future<void> refreshStatus({bool attemptSync = false}) async {
    state = AsyncValue.data(
      await _refreshInternal(
        attemptSync: attemptSync,
        keepSyncingStateWhileRunning: true,
      ),
    );
  }

  Future<void> syncNow() async {
    _consecutiveFailures = 0;
    _scheduleNextPoll();
    await refreshStatus(attemptSync: true);
  }

  Future<void> retryFailed({int? queueId}) async {
    await _appDb.syncQueue.requeueFailed(id: queueId);
    await refreshStatus(attemptSync: true);
  }

  Future<void> moveToDeadLetter({required int queueId}) async {
    await _appDb.syncQueue.markDead(queueId, 'Manually discarded by user.');
    await refreshStatus();
  }

  Future<void> reviveEntry({required int queueId}) async {
    await _appDb.syncQueue.reviveFromDead(queueId);
    await refreshStatus(attemptSync: true);
  }

  /// SYNC-02: merchant accepts the server's version of a conflicted record.
  /// The snapshot was already refreshed from the server when the conflict was
  /// detected, so this just clears the queue row.
  Future<void> keepServerVersion({required int queueId}) async {
    await _appDb.syncQueue.discardConflict(queueId);
    await refreshStatus();
  }

  /// SYNC-02: merchant chooses to re-send their local change for a conflicted
  /// record (e.g. after re-applying their edit on top of refreshed data).
  Future<void> retryConflict({required int queueId}) async {
    await _appDb.syncQueue.requeueConflict(queueId);
    await refreshStatus(attemptSync: true);
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final delaySecs = _consecutiveFailures == 0
        ? _minInterval.inSeconds
        : (_minInterval.inSeconds * (1 << _consecutiveFailures))
              .clamp(0, _maxInterval.inSeconds);
    _pollTimer = Timer(Duration(seconds: delaySecs), () async {
      await refreshStatus(attemptSync: true);
      _scheduleNextPoll();
    });
  }

  Future<SyncStatusSnapshot> _refreshInternal({
    required bool attemptSync,
    bool keepSyncingStateWhileRunning = false,
  }) async {
    if (_busy) {
      return state.valueOrNull ?? await _readSnapshot();
    }

    _busy = true;
    try {
      final reachable = await _pingBackend();
      // Persist the confirmed result so _readSnapshot can use it as a
      // reliable default while the next ping is in-flight.
      _lastKnownReachable = reachable;
      if (reachable) {
        // Reset the offline counter as soon as we're back.
        _consecutiveOfflinePings = 0;
      } else {
        _consecutiveOfflinePings++;
      }
      if (attemptSync && reachable) {
        if (keepSyncingStateWhileRunning) {
          final beforeSync = await _readSnapshot(
            backendReachable: true,
            isSyncing: true,
          );
          state = AsyncValue.data(beforeSync);
        }

        final result = await _runner.run();
        if (result.failed > 0) {
          _lastError = 'Some operations need retry.';
          _consecutiveFailures++;
        } else if (result.conflicts > 0) {
          _lastError = 'Server state changed. Local snapshot was refreshed.';
          _consecutiveFailures++;
        } else {
          _lastError = null;
          _consecutiveFailures = 0;
          if (result.applied > 0) {
            _lastSyncedAt = DateTime.now();
          }
        }
      } else if (attemptSync && !reachable) {
        _lastError = 'Backend unreachable.';
        _consecutiveFailures++;
      }

      return _readSnapshot(backendReachable: reachable);
    } catch (error) {
      _lastError = _humanizeError(error);
      _consecutiveFailures++;
      return _readSnapshot(backendReachable: false);
    } finally {
      _busy = false;
    }
  }

  Future<SyncStatusSnapshot> _readSnapshot({
    bool? backendReachable,
    bool isSyncing = false,
  }) async {
    final stats = await _appDb.syncQueue.stats();
    final failedEntries = await _appDb.syncQueue.failedRows();
    final conflictEntries = await _appDb.syncQueue.conflictRows();
    final deadEntries = await _appDb.syncQueue.deadRows();
    final snapshot = SyncStatusSnapshot(
      // Use _lastKnownReachable as the default if backendReachable is not
      // provided. This prevents a false 'Offline' indicator while the first
      // ping of a session is still in-flight. Only show false if we have
      // confirmed unreachability or no prior knowledge at all.
      backendReachable: backendReachable ?? _lastKnownReachable ?? false,
      isSyncing: isSyncing || stats.sendingCount > 0,
      stats: stats,
      failedEntries: failedEntries,
      conflictEntries: conflictEntries,
      deadEntries: deadEntries,
      lastError: _lastError,
      lastSyncedAt: _lastSyncedAt,
    );
    _maybeNotify(snapshot);
    return snapshot;
  }

  void _maybeNotify(SyncStatusSnapshot snapshot) {
    final prefs = ref.read(notificationPrefsProvider).valueOrNull;
    if (prefs == null || prefs.syncStatusEnabled != true) {
      _lastBackendReachable = snapshot.backendReachable;
      _lastPendingCount = snapshot.stats.pendingCount + snapshot.stats.sendingCount;
      _lastFailedCount = snapshot.stats.failedCount + snapshot.stats.conflictCount;
      return;
    }

    final backendReachable = snapshot.backendReachable;
    final pendingNow = snapshot.stats.pendingCount + snapshot.stats.sendingCount;
    final failedNow = snapshot.stats.failedCount + snapshot.stats.conflictCount;

    final notifications = ref.read(notificationsServiceProvider);

    // Offline transition — only notify after 2 consecutive offline pings
    // (~40 s) to avoid alerting on transient blips (Wi-Fi hand-off, brief
    // mobile dead-zone, etc). Once the notification fires, don't repeat it
    // on further poll ticks while still offline.
    if (_lastBackendReachable != false &&
        backendReachable == false &&
        _consecutiveOfflinePings >= 2) {
      unawaited(
        notifications.showSyncStatusNotification(
          title: 'Offline',
          body: 'Can\'t reach the server. Changes will sync when you\'re back online.',
          route: '/home',
        ),
      );
    }

    // Failures appearing
    if (failedNow > 0 && _lastFailedCount == 0) {
      unawaited(
        notifications.showSyncStatusNotification(
          title: 'Sync needs attention',
          body: '$failedNow operation${failedNow == 1 ? '' : 's'} failed. Tap to review.',
          route: '/home',
        ),
      );
    }

    // Pending work appears
    if (pendingNow > 0 && _lastPendingCount == 0 && backendReachable) {
      unawaited(
        notifications.showSyncStatusNotification(
          title: 'Sync in progress',
          body: '$pendingNow pending update${pendingNow == 1 ? '' : 's'} will be sent shortly.',
          route: '/home',
        ),
      );
    }

    _lastBackendReachable = backendReachable;
    _lastPendingCount = pendingNow;
    _lastFailedCount = failedNow;
  }

  Future<bool> _pingBackend() async {
    try {
      final response = await _apiClient.dio.get<dynamic>(
        '/health',
        options: Options(extra: {'skip_auth_header': true}),
      );
      final data = response.data;
      return data is Map<String, dynamic> && data['status'] == 'ok';
    } on DioException {
      return false;
    } on FormatException {
      return false;
    }
  }

  String _humanizeError(Object error) {
    return userFriendlyError(error);
  }

  Future<void> _maybePruneApplied() async {
    try {
      final kv = _appDb.kv;
      const pruneKey = 'sq_pruned_date';
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final last = await kv.get(pruneKey);
      if (last == '"$today"') return;
      await _appDb.syncQueue.pruneOldApplied();
      await kv.put(pruneKey, '"$today"');
    } catch (_) {
      // Never let cleanup failures block the UI boot path.
    }
  }
}
