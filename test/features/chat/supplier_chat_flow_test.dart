@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/domain/entities/chat.dart';
import 'package:mtc_app/features/chat/presentation/controllers/chat_controller.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';

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

  // `chat_conversations`/`chat_messages` have no anon-readable grant, and
  // `chat_messages_insert_participants` requires `sender_id` to actually
  // match the caller — every test below needs a real session, switching
  // between client1 (Awa) and fournisseur1 (Bogolan Bamako) whenever a
  // step acts as the other side.
  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'watchConversationsForSupplier only returns that supplier\'s own '
    'conversations',
    () async {
      await login('fournisseur1');

      final conversations = await container
          .read(chatRepositoryProvider)
          .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
          .first;

      expect(conversations, hasLength(1));
      expect(conversations.single.id, DemoIds.convAwaBogolan);
      expect(conversations.single.clientDisplayNameSnapshot, 'Awa Traoré');

      // Still logged in as fournisseur1 (Bogolan Bamako) — RLS restricts
      // this to Bogolan's own conversations regardless of which
      // supplierId is passed, so Electro Bamako's genuinely come back
      // empty rather than merely being filtered client-side.
      final none = await container
          .read(chatRepositoryProvider)
          .watchConversationsForSupplier(DemoIds.supplierElectroBamako)
          .first;
      expect(none, isEmpty);
    },
  );

  test(
    'a message from the client increments only the supplier\'s unread '
    "count, and vice versa — the two sides' counters are independent",
    () async {
      final repo = container.read(chatRepositoryProvider);
      const conversationId = DemoIds.convAwaBogolan;

      await login('client1');
      final before = (await repo
              .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
              .first)
          .single;
      expect(before.unreadCountSupplier, 0);

      await repo.sendMessage(
        conversationId: conversationId,
        senderId: DemoIds.clientAwa,
        text: 'Encore une question.',
      );

      final afterClientMessage = (await repo
              .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
              .first)
          .single;
      expect(afterClientMessage.unreadCountSupplier, 1);
      // The client's own unread count doesn't move for their own message.
      expect(afterClientMessage.unreadCountClient, 1);

      // `sender_id` must match the caller — switch to the supplier's own
      // session for their reply.
      await container.read(authRepositoryProvider).logout();
      await login('fournisseur1');
      await repo.sendMessage(
        conversationId: conversationId,
        senderId: DemoIds.supplierBogolanBamako,
        text: 'Réponse du fournisseur.',
      );

      final afterSupplierReply = (await repo
              .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
              .first)
          .single;
      // Supplier's own reply doesn't touch their own counter.
      expect(afterSupplierReply.unreadCountSupplier, 1);
      expect(afterSupplierReply.unreadCountClient, 2);
    },
  );

  test(
    'markConversationRead only clears the reader\'s own counter, leaving '
    "the other side's unread count untouched",
    () async {
      final repo = container.read(chatRepositoryProvider);
      const conversationId = DemoIds.convAwaBogolan;

      await login('client1');
      await repo.sendMessage(
        conversationId: conversationId,
        senderId: DemoIds.clientAwa,
        text: 'Question avant lecture côté fournisseur.',
      );

      await container.read(authRepositoryProvider).logout();
      await login('fournisseur1');
      await repo.markConversationRead(
        conversationId: conversationId,
        readBy: ChatParticipant.supplier,
      );

      final after = (await repo
              .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
              .first)
          .single;
      expect(after.unreadCountSupplier, 0);
      expect(after.unreadCountClient, greaterThan(0));
    },
  );

  test(
    'ChatController.markRead clears the supplier side when a signed-in '
    'supplier reads the thread, without the caller having to say so',
    () async {
      const conversationId = DemoIds.convAwaBogolan;

      await login('client1');
      await container
          .read(chatRepositoryProvider)
          .sendMessage(
            conversationId: conversationId,
            senderId: DemoIds.clientAwa,
            text: 'Question pour le fournisseur connecté.',
          );

      await container.read(authRepositoryProvider).logout();
      await login('fournisseur1');

      await container
          .read(chatControllerProvider.notifier)
          .markRead(conversationId);

      final after = (await container
              .read(chatRepositoryProvider)
              .watchConversationsForSupplier(DemoIds.supplierBogolanBamako)
              .first)
          .single;
      expect(after.unreadCountSupplier, 0);
    },
  );
}
