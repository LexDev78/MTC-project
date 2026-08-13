import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/in_memory_notification_datasource.dart';
import '../../data/repositories/in_memory_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationDatasourceProvider =
    Provider<InMemoryNotificationDatasource>((ref) {
      return InMemoryNotificationDatasource();
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((
  ref,
) {
  return InMemoryNotificationRepository(ref.watch(notificationDatasourceProvider));
});

final notificationsProvider =
    StreamProvider.family<List<AppNotification>, String>((ref, userId) {
      return ref.watch(notificationRepositoryProvider).watchForUser(userId);
    });

final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  userId,
) {
  final notifications = ref.watch(notificationsProvider(userId)).valueOrNull;
  return notifications?.where((n) => !n.isRead).length ?? 0;
});
