import 'package:flutter/foundation.dart';

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

  // Every caller shares its own `AsyncValue.guard` (or plain `await`) with
  // this call, sitting right after the real action it's about — an order
  // placed, a status changed, a message sent — has already succeeded.
  // Letting a delivery failure here (a network blip is the realistic
  // case; RLS shouldn't reject a well-formed call) propagate would falsely
  // report that already-successful action as failed, risking the caller
  // retrying and double-submitting it over what is, at worst, a missed
  // notification.
  @override
  Future<void> add({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? referenceId,
  }) async {
    try {
      await _datasource.add({
        'user_id': userId,
        'type': _typeToDb(type),
        'title': title,
        'body': body,
        'reference_id': referenceId,
      });
    } catch (e) {
      debugPrint('NotificationRepository.add failed (ignored): $e');
    }
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
}

String _typeToDb(NotificationType type) => switch (type) {
  NotificationType.newOrder => 'new_order',
  NotificationType.newMessage => 'new_message',
  NotificationType.lowStock => 'low_stock',
  NotificationType.kycDecision => 'kyc_decision',
  NotificationType.payoutDecision => 'payout_decision',
  NotificationType.newReview => 'new_review',
  NotificationType.orderStatusUpdate => 'order_status_update',
  NotificationType.newComment => 'new_comment',
  NotificationType.characteristicTypeDecision => 'characteristic_type_decision',
};
