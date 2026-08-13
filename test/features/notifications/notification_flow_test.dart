@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    'watchForUser only returns that user\'s own notifications, newest first',
    () async {
      final repo = container.read(notificationRepositoryProvider);
      await repo.add(
        userId: 'user-a',
        type: NotificationType.newOrder,
        title: 'A1',
        body: 'first',
      );
      await repo.add(
        userId: 'user-b',
        type: NotificationType.newOrder,
        title: 'B1',
        body: 'other user',
      );
      await repo.add(
        userId: 'user-a',
        type: NotificationType.lowStock,
        title: 'A2',
        body: 'second',
      );

      final forA = await repo.watchForUser('user-a').first;
      expect(forA.map((n) => n.title), ['A2', 'A1']);

      final forC = await repo.watchForUser('user-c').first;
      expect(forC, isEmpty);
    },
  );

  test(
    'a new notification starts unread; markRead/markAllRead flip isRead '
    'without touching other users\' notifications',
    () async {
      final repo = container.read(notificationRepositoryProvider);
      await repo.add(
        userId: 'user-a',
        type: NotificationType.newOrder,
        title: 'A1',
        body: 'x',
      );
      await repo.add(
        userId: 'user-a',
        type: NotificationType.newOrder,
        title: 'A2',
        body: 'y',
      );
      await repo.add(
        userId: 'user-b',
        type: NotificationType.newOrder,
        title: 'B1',
        body: 'z',
      );

      final before = await repo.watchForUser('user-a').first;
      expect(before.every((n) => !n.isRead), isTrue);

      await container
          .read(notificationControllerProvider.notifier)
          .markRead(before.firstWhere((n) => n.title == 'A1').id);

      final afterOne = await repo.watchForUser('user-a').first;
      expect(afterOne.firstWhere((n) => n.title == 'A1').isRead, isTrue);
      expect(afterOne.firstWhere((n) => n.title == 'A2').isRead, isFalse);

      await container
          .read(notificationControllerProvider.notifier)
          .markAllRead('user-a');

      final afterAll = await repo.watchForUser('user-a').first;
      expect(afterAll.every((n) => n.isRead), isTrue);

      final untouchedB = await repo.watchForUser('user-b').first;
      expect(untouchedB.single.isRead, isFalse);
    },
  );
}
