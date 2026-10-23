import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/domain/entities/chat.dart';
import 'package:mtc_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart';
import 'package:mtc_app/features/chat/presentation/screens/conversation_list_screen.dart';
import 'package:mtc_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// Les discussions du client, fermées ou non : la conversation et la liste.

ChatConversation _conversation({
  required String id,
  required String boutique,
  required String apercu,
  int nonLus = 0,
  DateTime? fermee,
}) => ChatConversation(
  id: id,
  clientId: 'client-awa',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierId: 'boutique-$id',
  supplierName: boutique,
  lastMessagePreview: apercu,
  lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
  unreadCountClient: nonLus,
  unreadCountSupplier: 0,
  closedAt: fermee,
);

class _Discussions implements ChatRepository {
  _Discussions(this.conversations);

  final List<ChatConversation> conversations;

  @override
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId) =>
      Stream.value(conversations);

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      Stream.value([
        ChatMessage(
          id: 'm1',
          conversationId: conversationId,
          senderId: 'client-awa',
          text: 'Bonjour, le tissu est-il disponible en bleu ?',
          sentAt: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
        ),
        ChatMessage(
          id: 'm2',
          conversationId: conversationId,
          senderId: 'boutique-$conversationId',
          text: 'Oui, en bleu indigo. Nous avons aussi une promotion ce mois-ci !',
          sentAt: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
        ),
      ]);

  @override
  Future<void> markConversationRead({
    required String conversationId,
    required ChatParticipant readBy,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Notifs implements NotificationRepository {
  @override
  Future<void> markReadByReference({
    required String userId,
    required String referenceId,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _fermee = _conversation(
  id: 'c1',
  boutique: 'Bogolan Bamako',
  apercu: 'Oui, en bleu indigo.',
  fermee: DateTime.now().subtract(const Duration(days: 1)),
);

List<Override> _discussions(List<ChatConversation> conversations) => [
  currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
  chatRepositoryProvider.overrideWithValue(_Discussions(conversations)),
  notificationRepositoryProvider.overrideWithValue(_Notifs()),
];

void main() {
  setUp(() {
    // La zone de saisie crée un enregistreur audio natif : sans plateforme,
    // son canal répond simplement.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
  });

  capturerEcran(
    'discussion_fermee',
    () => const ChatThreadScreen(conversationId: 'c1'),
    overrides: () => _discussions([_fermee]),
  );
  capturerEcran(
    'discussion_menu',
    () => const ChatThreadScreen(conversationId: 'c2'),
    overrides: () => _discussions([
      _conversation(id: 'c2', boutique: 'Electro Bamako', apercu: 'Merci !'),
    ]),
    geste: (tester) async {
      await tester.tap(find.byTooltip('Options de la conversation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  capturerEcran(
    'messages_fermee',
    () => const ConversationListScreen(),
    overrides: () => _discussions([
      _conversation(
        id: 'c2',
        boutique: 'Electro Bamako',
        apercu: 'Votre colis part demain matin.',
        nonLus: 2,
      ),
      _fermee,
    ]),
  );
}
