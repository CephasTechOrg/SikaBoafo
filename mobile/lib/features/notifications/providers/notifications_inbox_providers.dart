import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/core_providers.dart';
import '../data/notifications_inbox_repository.dart';

final notificationsInboxRepositoryProvider =
    Provider<NotificationsInboxRepository>((ref) {
  return NotificationsInboxRepository(ref.watch(appDatabaseProvider));
});

final notificationsInboxControllerProvider =
    AsyncNotifierProvider<NotificationsInboxController, List<InboxNotification>>(
  NotificationsInboxController.new,
);

class NotificationsInboxController extends AsyncNotifier<List<InboxNotification>> {
  @override
  Future<List<InboxNotification>> build() async {
    return ref.read(notificationsInboxRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationsInboxRepositoryProvider).list(),
    );
  }

  Future<void> markRead(int id) async {
    await ref.read(notificationsInboxRepositoryProvider).markRead(id);
    await refresh();
  }

  Future<void> markAllRead() async {
    await ref.read(notificationsInboxRepositoryProvider).markAllRead();
    await refresh();
  }

  Future<void> deleteOne(int id) async {
    await ref.read(notificationsInboxRepositoryProvider).deleteOne(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await ref.read(notificationsInboxRepositoryProvider).clearAll();
    await refresh();
  }

  Future<void> record({
    required int notificationId,
    required String type,
    required String title,
    required String body,
    required String route,
    String? entityId,
    Object? payload,
  }) async {
    await ref.read(notificationsInboxRepositoryProvider).upsertFromLocalNotification(
          notificationId: notificationId,
          type: type,
          title: title,
          body: body,
          route: route,
          entityId: entityId,
          payloadJson: payload == null ? null : jsonEncode(payload),
        );
    await refresh();
  }
}

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationsInboxRepositoryProvider).unreadCount();
});

final unreadNotificationsCountLiveProvider = Provider<int>((ref) {
  final listAsync = ref.watch(notificationsInboxControllerProvider);
  final items = listAsync.valueOrNull;
  if (items == null) return 0;
  return items.where((n) => !n.isRead).length;
});

