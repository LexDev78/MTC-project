import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/notifications/presentation/screens/client_notifications_screen.dart';
import 'package:mtc_app/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

/// Enregistre les accusés de lecture sans jamais les terminer : un réseau
/// lent, où le serveur n'a pas encore répondu.
class _ReseauLent extends NotificationController {
  _ReseauLent(this.envois);

  final List<String> envois;

  @override
  Future<void> markRead(String notificationId) {
    envois.add(notificationId);
    return Completer<void>().future;
  }

  @override
  Future<void> markAllRead(String userId) {
    envois.add('tout');
    return Completer<void>().future;
  }
}

AppNotification _notification(
  String id, {
  required bool lue,
  String? commande,
}) => AppNotification(
  id: id,
  userId: 'client-1',
  type: NotificationType.orderStatusUpdate,
  title: 'Titre $id',
  body: 'Votre commande avance.',
  createdAt: DateTime(2026, 10, 18, 8),
  isRead: lue,
  referenceId: commande,
);

// Demandé le 18/10/2026 : « le compteur de notification doit s'afficher
// devant la notif non lue et disparaître quand je regarde la notif ». Une
// notification non lue ne se distinguait que par une teinte de fond, et
// l'ouvrir attendait la réponse du serveur.
//
// Les mêmes scénarios passent sur les deux écrans — celui des fournisseurs
// et celui du client, au style du kit — puisqu'ils partagent leur logique.
void main() {
  scenarios('écran fournisseur', () => const NotificationCenterScreen());
  scenarios(
    'écran client (kit)',
    () => const ShopScope(child: ClientNotificationsScreen()),
  );
}

void scenarios(String nom, Widget Function() ecran) => group(nom, () {
  late List<String> envois;

  Future<void> monter(WidgetTester tester) async {
    envois = [];
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(path: '/notifications', builder: (_, _) => ecran()),
        GoRoute(
          path: '/client/orders/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Commande ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(
              AppUser.client(
                id: 'client-1',
                displayName: 'Awa Traoré',
                usernameOrPhone: 'client1',
                phoneNumber: '70000000',
                createdAt: DateTime(2026),
              ),
            ),
          ),
          operatingSupplierIdProvider.overrideWithValue(null),
          supplierRoutePrefixProvider.overrideWithValue('/fournisseur'),
          notificationsProvider('client-1').overrideWith(
            (ref) => Stream.value([
              _notification('n1', lue: false),
              _notification('n2', lue: false, commande: 'cmd-42'),
              _notification('n3', lue: true),
            ]),
          ),
          notificationControllerProvider.overrideWith(
            () => _ReseauLent(envois),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder pastille(String id) => find.byKey(ValueKey('non-lue-$id'));
  Finder compteur(String texte) => find.descendant(
    of: find.byKey(const ValueKey('compteur-non-lues')),
    matching: find.text(texte),
  );

  testWidgets('chaque notification non lue porte une pastille, et l\'écran '
      'dit combien', (tester) async {
    await monter(tester);

    expect(pastille('n1'), findsOneWidget);
    expect(pastille('n2'), findsOneWidget);
    expect(pastille('n3'), findsNothing);
    expect(compteur('2'), findsOneWidget);
  });

  testWidgets('l\'ouvrir retire sa pastille tout de suite, même si le serveur '
      'tarde', (tester) async {
    await monter(tester);

    await tester.tap(find.text('Titre n1'));
    await tester.pump();

    expect(pastille('n1'), findsNothing);
    expect(compteur('1'), findsOneWidget);
    expect(envois, ['n1']);
  });

  testWidgets('la commande s\'ouvre sans attendre l\'accusé de lecture', (
    tester,
  ) async {
    await monter(tester);

    await tester.tap(find.text('Titre n2'));
    await tester.pumpAndSettle();

    expect(find.text('Commande cmd-42'), findsOneWidget);
    expect(envois, ['n2']);
  });

  testWidgets('une notification déjà lue ne repart pas au serveur', (
    tester,
  ) async {
    await monter(tester);

    await tester.tap(find.text('Titre n3'));
    await tester.pump();

    expect(envois, isEmpty);
  });

  testWidgets('tout marquer comme lu retire pastilles et compteur', (
    tester,
  ) async {
    await monter(tester);

    await tester.tap(find.byTooltip('Tout marquer comme lu'));
    await tester.pump();

    expect(pastille('n1'), findsNothing);
    expect(pastille('n2'), findsNothing);
    expect(find.byKey(const ValueKey('compteur-non-lues')), findsNothing);
    expect(envois, ['tout']);

    // Plus rien à marquer : le bouton se désactive.
    await tester.tap(find.byTooltip('Tout marquer comme lu'));
    await tester.pump();
    expect(envois, ['tout']);
  });
});
