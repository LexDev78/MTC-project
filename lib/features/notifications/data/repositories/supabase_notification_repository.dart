import '../../domain/entities/app_notification.dart';
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
  Future<void> add({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) {
    return _datasource.add({
      'user_id': userId,
      'type': _typeToDb(type),
      'title': title,
      'body': body,
      'reference_id': referenceId,
    });
  }

  @override
  Future<void> markRead(String notificationId) {
    return _datasource.markRead(notificationId);
  }

  @override
  Future<void> markAllRead(String userId) {
    return _datasource.markAllRead(userId);
  }
}

String _typeToDb(NotificationType type) => switch (type) {
  NotificationType.newOrder => 'new_order',
  NotificationType.newMessage => 'new_message',
  NotificationType.lowStock => 'low_stock',
  NotificationType.kycDecision => 'kyc_decision',
  NotificationType.payoutDecision => 'payout_decision',
  NotificationType.newReview => 'new_review',
  NotificationType.orderStatusUpdate => 'order_status_update',
};
