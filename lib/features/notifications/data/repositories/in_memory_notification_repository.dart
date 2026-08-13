import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/in_memory_notification_datasource.dart';

class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository(this._datasource);

  final InMemoryNotificationDatasource _datasource;

  @override
  Stream<List<AppNotification>> watchForUser(String userId) {
    return _datasource.watchAll().map(
      (notifications) =>
          notifications.where((n) => n.userId == userId).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<void> add({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
  }) async {
    _datasource.add(userId: userId, type: type, title: title, body: body);
  }

  @override
  Future<void> markRead(String notificationId) async {
    _datasource.markRead(notificationId);
  }

  @override
  Future<void> markAllRead(String userId) async {
    _datasource.markAllRead(userId);
  }
}
