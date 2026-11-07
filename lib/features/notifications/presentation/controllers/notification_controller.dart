import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notification_providers.dart';

class NotificationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> markRead(String notificationId) async {
    await ref.read(notificationRepositoryProvider).markRead(notificationId);
  }

  Future<void> markAllRead(String userId) async {
    await ref.read(notificationRepositoryProvider).markAllRead(userId);
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, void>(
      NotificationController.new,
    );
