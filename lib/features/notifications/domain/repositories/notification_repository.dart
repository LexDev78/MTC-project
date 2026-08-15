import '../entities/app_notification.dart';

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String userId);

  Future<void> add({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  });

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);
}
