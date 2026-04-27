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
import '../../features/inventory/data/inventory_api.dart';
import 'core_providers.dart';

class SyncStatusSnapshot {
  const SyncStatusSnapshot({
    required this.backendReachable,
    required this.isSyncing,
    required this.stats,
    required this.failedEntries,
    required this.deadEntries,
    this.lastError,
    this.lastSyncedAt,
  });

  final bool backendReachable;
  final bool isSyncing;
  final SyncQueueStats stats;
  final List<SyncQueueEntry> failedEntries;
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

final syncStatusControllerProvider =
    AsyncNotifierProvider.autoDispose<SyncStatusController, SyncStatusSnapshot>(
  SyncStatusController.new,
);

class SyncStatusController
    extends AutoDisposeAsyncNotifier<SyncStatusSnapshot> {
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
    final deadEntries = await _appDb.syncQueue.deadRows();
    return SyncStatusSnapshot(
      backendReachable: backendReachable ?? false,
      isSyncing: isSyncing || stats.sendingCount > 0,
      stats: stats,
      failedEntries: failedEntries,
      deadEntries: deadEntries,
      lastError: _lastError,
      lastSyncedAt: _lastSyncedAt,
    );
  }

  Future<bool> _pingBackend() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/health');
      final data = response.data;
      return data is Map<String, dynamic> && data['status'] == 'ok';
    } on DioException {
      return false;
    } on FormatException {
      return false;
    }
  }

  String _humanizeError(Object error) {
    if (error is DioException) {
      return error.message ?? 'Sync request failed.';
    }
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
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
