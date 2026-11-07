
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/supabase_notification_datasource.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._datasource);

  final SupabaseNotificationDatasource _datasource;

  @override
  Stream<List<AppNotification>> watchForUser(String userId) {
    return _datasource
        .watchForUser(userId)
        .map((rows) => rows.map(AppNotification.fromJson).toList());
  }

  @override
  Future<void> markRead(String notificationId) {
    return _datasource.markRead(notificationId);
  }

  @override
  Future<void> markAllRead(String userId) {
    return _datasource.markAllRead(userId);
  }

  @override
  Future<void> markReadByReference({
    required String userId,
    required String referenceId,
  }) {
    return _datasource.markReadByReference(
      userId: userId,
      referenceId: referenceId,
    );
  }

  @override
  Future<NotificationPreferences> fetchPreferences(String userId) async {
    return NotificationPreferences.fromRow(
      await _datasource.fetchPreferences(userId),
    );
  }

  @override
  Future<void> savePreferences(
    String userId,
    NotificationPreferences preferences,
  ) {
    return _datasource.savePreferences(preferences.toRow(userId));
  }
}
