@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
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

  // `notifications` has no anon-readable grant, and `user_id` is a real
  // `uuid` column — needs a logged-in session with a real seeded account
  // id, not a bare string like the old in-memory-era 'user-a'/'user-b'.
  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'watchForUser only returns that user\'s own notifications, newest first',
    () async {
      await login('client1');
      final repo = container.read(notificationRepositoryProvider);
      // Inserting a notification for someone else is allowed (any signed-in
      // account can notify any other, `notifications_insert_authenticated`)
      // — only reading someone else's back is restricted.
      await repo.add(
        userId: DemoIds.clientAwa,
        type: NotificationType.newOrder,
        title: 'A1',
        body: 'first',
      );
      await repo.add(
        userId: DemoIds.clientMoussa,
        type: NotificationType.newOrder,
        title: 'B1',
        body: 'other user',
      );
      await repo.add(
        userId: DemoIds.clientAwa,
        type: NotificationType.lowStock,
        title: 'A2',
        body: 'second',
      );

      final forA = await repo.watchForUser(DemoIds.clientAwa).first;
      expect(forA.map((n) => n.title), ['A2', 'A1']);

      // A user with zero notifications sees none — checked via the admin
      // bypass so this genuinely tests query scoping rather than RLS
      // merely hiding another party's rows from client1's own session.
      final forStaff = await fetchNotificationsForUserAsAdmin(DemoIds.staffAdmin);
      expect(forStaff, isEmpty);
    },
  );

  test(
    'a new notification starts unread; markRead/markAllRead flip isRead '
    'without touching other users\' notifications',
    () async {
      await login('client1');
      final repo = container.read(notificationRepositoryProvider);
      await repo.add(
        userId: DemoIds.clientAwa,
        type: NotificationType.newOrder,
        title: 'A1',
        body: 'x',
      );
      await repo.add(
        userId: DemoIds.clientAwa,
        type: NotificationType.newOrder,
        title: 'A2',
        body: 'y',
      );
      await repo.add(
        userId: DemoIds.clientMoussa,
        type: NotificationType.newOrder,
        title: 'B1',
        body: 'z',
      );

      final before = await repo.watchForUser(DemoIds.clientAwa).first;
      expect(before.every((n) => !n.isRead), isTrue);

      await container
          .read(notificationControllerProvider.notifier)
          .markRead(before.firstWhere((n) => n.title == 'A1').id);

      final afterOne = await repo.watchForUser(DemoIds.clientAwa).first;
      expect(afterOne.firstWhere((n) => n.title == 'A1').isRead, isTrue);
      expect(afterOne.firstWhere((n) => n.title == 'A2').isRead, isFalse);

      await container
          .read(notificationControllerProvider.notifier)
          .markAllRead(DemoIds.clientAwa);

      final afterAll = await repo.watchForUser(DemoIds.clientAwa).first;
      expect(afterAll.every((n) => n.isRead), isTrue);

      // Moussa (client2) isn't the signed-in session — read via the admin
      // bypass to confirm `markAllRead('client1's id')` never touched it.
      final untouchedB = await fetchNotificationsForUserAsAdmin(DemoIds.clientMoussa);
      expect(untouchedB.single['is_read'], isFalse);
    },
  );
}
