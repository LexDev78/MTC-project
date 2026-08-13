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

  test(
    'sending a message appends it and updates the conversation preview + unread count',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      const conversationId = 'conv-awa-bogolan';

      final before = await container
          .read(chatRepositoryProvider)
          .watchMessages(conversationId)
          .first;
      expect(before, hasLength(2));

      await container
          .read(chatControllerProvider.notifier)
          .sendMessage(
            conversationId: conversationId,
            text: 'Je voudrais en commander 3.',
          );

      final after = await container
          .read(chatRepositoryProvider)
          .watchMessages(conversationId)
          .first;
      expect(after, hasLength(3));
      expect(after.last.text, 'Je voudrais en commander 3.');
      expect(after.last.senderId, DemoIds.clientAwa);

      final conversations = await container
          .read(chatRepositoryProvider)
          .watchConversationsForUser(DemoIds.clientAwa)
          .first;
      final conversation = conversations.firstWhere(
        (c) => c.id == conversationId,
      );
      expect(conversation.lastMessagePreview, 'Je voudrais en commander 3.');
    },
  );

  test(
    'starting a conversation twice with the same supplier reuses the same thread',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client2', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final repo = container.read(chatRepositoryProvider);
      final firstId = await repo.startOrGetConversation(
        clientId: DemoIds.clientMoussa,
        clientDisplayNameSnapshot: 'Moussa Diarra',
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
      );
      final secondId = await repo.startOrGetConversation(
        clientId: DemoIds.clientMoussa,
        clientDisplayNameSnapshot: 'Moussa Diarra',
        supplierId: DemoIds.supplierElectroBamako,
        supplierName: 'Electro Bamako',
      );

      expect(firstId, secondId);
    },
  );

  test('marking a conversation read clears its unread count', () async {
    final repo = container.read(chatRepositoryProvider);
    const conversationId = 'conv-awa-bogolan';

    final before = await repo
        .watchConversationsForUser(DemoIds.clientAwa)
        .first;
    expect(
      before.firstWhere((c) => c.id == conversationId).unreadCountClient,
      greaterThan(0),
    );

    await repo.markConversationRead(
      conversationId: conversationId,
      readBy: ChatParticipant.client,
    );

    final after = await repo.watchConversationsForUser(DemoIds.clientAwa).first;
    expect(
      after.firstWhere((c) => c.id == conversationId).unreadCountClient,
      0,
    );
  });
}
