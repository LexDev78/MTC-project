@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
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
      // Les fixtures passent par le harnais : une session cliente ne peut
      // plus insérer de notification (`0064` — elles sont produites par
      // l'événement qui les justifie). Ce test porte sur la **lecture**,
      // c'est-à-dire sur ce que chacun voit de ce qui a été posé.
      await insertNotificationAsAdmin(
        userId: DemoIds.clientAwa,
        type: 'new_order',
        title: 'A1',
        body: 'first',
      );
      await insertNotificationAsAdmin(
        userId: DemoIds.clientMoussa,
        type: 'new_order',
        title: 'B1',
        body: 'other user',
      );
      await insertNotificationAsAdmin(
        userId: DemoIds.clientAwa,
        type: 'low_stock',
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
      await insertNotificationAsAdmin(
        userId: DemoIds.clientAwa,
        type: 'new_order',
        title: 'A1',
        body: 'x',
      );
      await insertNotificationAsAdmin(
        userId: DemoIds.clientAwa,
        type: 'new_order',
        title: 'A2',
        body: 'y',
      );
      await insertNotificationAsAdmin(
        userId: DemoIds.clientMoussa,
        type: 'new_order',
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
