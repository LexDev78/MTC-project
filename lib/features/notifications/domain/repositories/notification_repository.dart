import '../entities/app_notification.dart';

/// Lecture et marquage des notifications. **Pas d'écriture** : depuis
/// `0064` et `0069`, chaque notification est produite par l'événement qui la
/// justifie, côté serveur, et `notifications` n'a plus aucune policy
/// d'insertion. Une méthode `add` ici ne pourrait qu'échouer — et inviterait
/// à rouvrir la policy pour la faire marcher.
abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchForUser(String userId);

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
