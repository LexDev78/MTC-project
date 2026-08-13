import 'dart:async';

import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/app_notification.dart';

class InMemoryNotificationDatasource {
  final List<AppNotification> _notifications = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<AppNotification>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map(
      (_) => List<AppNotification>.unmodifiable(_notifications),
    );
  }

  void add({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
  }) {
    _notifications.add(
      AppNotification(
        id: IdGenerator.next(),
        userId: userId,
        type: type,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        isRead: false,
      ),
    );
    _changesController.add(null);
  }

  void markRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;
    _notifications[index] = _notifications[index].copyWith(isRead: true);
    _changesController.add(null);
  }

  void markAllRead(String userId) {
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == userId && !_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) _changesController.add(null);
  }
}
