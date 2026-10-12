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

  /// Marks every unread notification pointing at [referenceId] (e.g. a chat
  /// conversation id) as read for [userId] — used when the user is already
  /// looking at whatever the notification would have sent them to, so it
  /// never needs to surface as unread in the first place.
  Future<void> markReadByReference({
    required String userId,
    required String referenceId,
  });
}
