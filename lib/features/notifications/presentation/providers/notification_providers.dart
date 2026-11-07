import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_notification_datasource.dart';
import '../../data/repositories/supabase_notification_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

final notificationDatasourceProvider =
    Provider<SupabaseNotificationDatasource>((ref) {
      return SupabaseNotificationDatasource(ref.watch(supabaseClientProvider));
    });

final notificationRepositoryProvider = Provider<NotificationRepository>((
  ref,
) {
  return SupabaseNotificationRepository(ref.watch(notificationDatasourceProvider));
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
