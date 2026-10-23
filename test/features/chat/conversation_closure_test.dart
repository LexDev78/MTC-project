import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/domain/entities/chat.dart';
import 'package:mtc_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/chat/presentation/screens/chat_thread_screen.dart';
import 'package:mtc_app/features/chat/presentation/widgets/chat_composer.dart';
import 'package:mtc_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../support/shop_fixtures.dart';

/// La fermeture d'une conversation par le client, vue des deux côtés, sans
/// base : ce que chacun voit, ce qui part au serveur, et un refus dit.

const _conversationId = 'conv-1';
const _boutiqueId = 'boutique-1';

/// Les conversations et les messages, en mémoire. Fermer ou rouvrir pousse
/// la conversation à jour dans le flux, comme le ferait le temps réel.
class _Discussions implements ChatRepository {
  _Discussions({required bool fermee})
    : _conversation = ChatConversation(
        id: _conversationId,
        clientId: 'client-awa',
        clientDisplayNameSnapshot: 'Awa Traoré',
        supplierId: _boutiqueId,
        supplierName: 'Bogolan Bamako',
        lastMessagePreview: 'Oui, disponible.',
        lastMessageAt: DateTime(2026, 10, 21, 9),
        unreadCountClient: 0,
        unreadCountSupplier: 0,
        closedAt: fermee ? DateTime(2026, 10, 21, 10) : null,
      );

  ChatConversation _conversation;
  final _conversations = StreamController<List<ChatConversation>>.broadcast();

  /// Chaque fermeture (`true`) ou réouverture (`false`) demandée.
  final fermetures = <bool>[];
  final envois = <String>[];

  /// Si posé, l'envoi échoue avec lui.
  Object? refusEnvoi;

  Stream<List<ChatConversation>> _flux() async* {
    yield [_conversation];
    yield* _conversations.stream;
  }

  @override
  Stream<List<ChatConversation>> watchConversationsForUser(String clientId) =>
      _flux();

  @override
  Stream<List<ChatConversation>> watchConversationsForSupplier(
    String supplierId,
  ) => _flux();

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) =>
      Stream.value([
        ChatMessage(
          id: 'm1',
          conversationId: _conversationId,
          senderId: _boutiqueId,
          text: 'Oui, disponible.',
          sentAt: DateTime(2026, 10, 21, 9),
          isRead: true,
        ),
      ]);

  @override
  Future<DateTime?> setConversationClosed({
    required String conversationId,
    required bool closed,
  }) async {
    fermetures.add(closed);
    _conversation = _conversation.copyWith(
      closedAt: closed ? DateTime(2026, 10, 22) : null,
    );
    _conversations.add([_conversation]);
    return _conversation.closedAt;
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? productId,
    String? productNameSnapshot,
    String? productImageSnapshot,
    int? productPriceFcfaSnapshot,
    String? productVariantId,
    String? productVariantNameSnapshot,
    ChatAttachmentType attachmentType = ChatAttachmentType.none,
    String? attachmentPath,
    int? voiceDurationSeconds,
  }) async {
    if (refusEnvoi != null) throw refusEnvoi!;
    envois.add(text);
  }

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

final _boutique = AppUser.supplierTiers(
  id: _boutiqueId,
  displayName: 'Ibrahima Coulibaly',
  usernameOrPhone: 'fournisseur1',
  phoneNumber: '+22376000001',
  createdAt: DateTime(2026),
  businessName: 'Bogolan Bamako',
  verificationStatus: VerificationStatus.verified,
  city: 'Bamako',
  ratingAverage: 4.5,
  ratingCount: 3,
  legalType: SupplierLegalType.company,
);

late _Discussions _depot;

Future<void> _ouvrir(
  WidgetTester tester, {
  required AppUser compte,
  required bool fermee,
}) async {
  tester.view.physicalSize = const Size(375, 800) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _depot = _Discussions(fermee: fermee);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(compte)),
        chatRepositoryProvider.overrideWithValue(_depot),
        notificationRepositoryProvider.overrideWithValue(_Notifs()),
        operatingSupplierIdProvider.overrideWithValue(
          compte is ClientUser ? null : _boutiqueId,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const ChatThreadScreen(conversationId: _conversationId),
      ),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

const _bandeauClient =
    'Vous avez fermé cette conversation : la boutique ne peut plus vous '
    'écrire. Votre prochain message la rouvre.';
const _bandeauBoutique =
    'Ce client a fermé la conversation : vous ne pouvez plus lui écrire.';

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

  testWidgets('le client ferme la conversation, après confirmation', (
    tester,
  ) async {
    await _ouvrir(tester, compte: clientAwa(), fermee: false);
    expect(find.text(_bandeauClient), findsNothing);

    await tester.tap(find.byTooltip('Options de la conversation'));
    await _avancer(tester);
    await tester.tap(find.text('Fermer la conversation'));
    await _avancer(tester);
    expect(find.text('Fermer la conversation ?'), findsOneWidget);

    // Annuler ne ferme rien.
    await tester.tap(find.text('Annuler'));
    await _avancer(tester);
    expect(_depot.fermetures, isEmpty);

    await tester.tap(find.byTooltip('Options de la conversation'));
    await _avancer(tester);
    await tester.tap(find.text('Fermer la conversation'));
    await _avancer(tester);
    await tester.tap(find.text('Fermer'));
    await _avancer(tester);

    expect(_depot.fermetures, [true]);
    expect(
      find.text('Conversation fermée : la boutique ne peut plus vous écrire.'),
      findsOneWidget,
    );
    expect(find.text(_bandeauClient), findsOneWidget);
    // Le client garde de quoi écrire : c'est ainsi qu'il rouvre.
    expect(find.byType(ChatComposer), findsOneWidget);
  });

  testWidgets('le client rouvre d\'un geste', (tester) async {
    await _ouvrir(tester, compte: clientAwa(), fermee: true);
    expect(find.text(_bandeauClient), findsOneWidget);

    await tester.tap(find.text('Rouvrir'));
    await _avancer(tester);

    expect(_depot.fermetures, [false]);
    expect(find.text(_bandeauClient), findsNothing);
  });

  testWidgets('la boutique voit la fermeture, sans zone de saisie', (
    tester,
  ) async {
    await _ouvrir(tester, compte: _boutique, fermee: true);

    expect(find.text(_bandeauBoutique), findsOneWidget);
    expect(find.byType(ChatComposer), findsNothing);
    // Ni menu ni « Rouvrir » : la porte est au client.
    expect(find.byTooltip('Options de la conversation'), findsNothing);
    expect(find.text('Rouvrir'), findsNothing);
    // Les messages restent lisibles.
    expect(find.text('Oui, disponible.'), findsOneWidget);
  });

  testWidgets('un envoi refusé le dit au lieu de disparaître', (tester) async {
    await _ouvrir(tester, compte: _boutique, fermee: false);
    expect(find.byType(ChatComposer), findsOneWidget);
    _depot.refusEnvoi = const ValidationException(
      'Ce client a fermé la conversation : vous ne pouvez plus lui écrire.',
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(ChatComposer),
        matching: find.byType(TextField),
      ),
      'Bonjour !',
    );
    // La touche « Envoyer » du clavier : la zone de saisie envoie à la
    // validation du champ.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await _avancer(tester);

    expect(_depot.envois, isEmpty);
    expect(
      find.text(
        'Ce client a fermé la conversation : vous ne pouvez plus lui écrire.',
      ),
      findsOneWidget,
    );
  });
}
