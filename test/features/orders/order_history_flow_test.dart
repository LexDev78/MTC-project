import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/repositories/order_repository.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_cancel_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_list_screen.dart';
import 'package:mtc_app/features/orders/presentation/widgets/order_cards.dart';

import '../../support/order_fixtures.dart';

/// L'historique des commandes du kit, sans base : rubriques et comptes,
/// recherche, période, fiche d'une commande et annulation d'une part.

/// Le dépôt des commandes, réduit à l'annulation : il note ce qu'on lui
/// demande, ou refuse avec [refus].
class _Commandes implements OrderRepository {
  final annulations = <Map<Symbol, dynamic>>[];
  Object? refus;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateGroupStatus) {
      if (refus != null) return Future<void>.error(refus!);
      annulations.add(invocation.namedArguments);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

late _Commandes _depot;

Future<void> _ouvrir(
  WidgetTester tester,
  String adresse, {
  List<Order>? commandes,
}) async {
  // Assez haut pour que toute la fiche soit construite : une liste ne bâtit
  // pas ce qui est sous le pli.
  tester.view.physicalSize = const Size(375, 2600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _depot = _Commandes();
  Page<void> page(Widget ecran) => MaterialPage(child: ShopScope(child: ecran));
  final router = GoRouter(
    initialLocation: adresse,
    routes: [
      GoRoute(
        path: AppRoutes.clientOrders,
        pageBuilder: (_, _) => page(const OrderListScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientOrdersByCategory,
        pageBuilder: (_, state) => page(
          OrdersByCategoryScreen(
            category: OrderHistoryCategory.values.byName(
              state.pathParameters['category']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientOrderDetail,
        pageBuilder: (_, state) =>
            page(OrderDetailScreen(orderId: state.pathParameters['orderId']!)),
      ),
      GoRoute(
        path: AppRoutes.clientOrderCancel,
        pageBuilder: (_, state) => page(
          OrderCancelScreen(
            orderId: state.pathParameters['orderId']!,
            groupId: state.pathParameters['groupId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.clientOrderTrack,
        pageBuilder: (_, _) => page(const Scaffold(body: Text('SUIVI'))),
      ),
      GoRoute(
        path: AppRoutes.clientOrderReview,
        // La part à noter voyage avec le lien : c'est elle qu'on vérifie.
        pageBuilder: (_, state) => page(
          Scaffold(body: Text('AVIS ${state.uri.queryParameters['group']}')),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...donneesCommandes(commandes: commandes),
        orderRepositoryProvider.overrideWithValue(_depot),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester, {int pas = 6}) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
  await _avancer(tester);
}

/// Le compte affiché sur la rubrique [libelle] de l'historique.
String _compte(WidgetTester tester, String libelle) {
  final ligne = find.ancestor(
    of: find.text(libelle),
    matching: find.byType(StatusCountTile),
  );
  return tester.widget<StatusCountTile>(ligne).count.toString();
}

/// Le bouton rouge du bas de l'écran d'annulation.
BottomActionBar _barre(WidgetTester tester) =>
    tester.widget<BottomActionBar>(find.byType(BottomActionBar));

void main() {
  testWidgets('l\'historique compte par rubrique et mène aux commandes', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.clientOrders);

    expect(_compte(tester, 'En attente'), '1');
    expect(_compte(tester, 'En préparation'), '0');
    expect(_compte(tester, 'En livraison'), '1');
    expect(_compte(tester, 'Livrées'), '1');
    expect(_compte(tester, 'Annulées'), '1');

    await _toucher(tester, find.text('Livrées'));
    expect(find.text('Commande ${'#8C41F0D2'}'), findsOneWidget);
    expect(find.text('Tissu bogolan traditionnel'), findsOneWidget);
    // Deux articles par carte, le troisième annoncé.
    expect(find.text('et 1 autre article'), findsOneWidget);
    expect(find.text('Commande #2D9A6C0E'), findsNothing);

    await _toucher(tester, find.text('Tissu bogolan traditionnel'));
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Commande #8C41F0D2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('la recherche trouve par article, boutique ou numéro', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.clientOrders);
    final champ = find.byType(TextField);

    await tester.enterText(champ, 'miel');
    await _avancer(tester);
    expect(find.text('Commande #B7E2A915'), findsOneWidget);
    expect(find.byType(OrderCard), findsOneWidget);
    // Les rubriques laissent la place aux résultats.
    expect(find.byType(StatusCountTile), findsNothing);

    // Sans accent ni majuscule : la boutique est « Coopérative de Kita ».
    await tester.enterText(champ, 'cooperative');
    await _avancer(tester);
    expect(find.text('Commande #B7E2A915'), findsOneWidget);

    await tester.enterText(champ, '8c41');
    await _avancer(tester);
    expect(find.text('Commande #8C41F0D2'), findsOneWidget);
    expect(find.byType(OrderCard), findsOneWidget);

    await tester.enterText(champ, 'parapluie');
    await _avancer(tester);
    expect(find.text('Aucune commande trouvée'), findsOneWidget);

    await tester.enterText(champ, '');
    await _avancer(tester);
    expect(find.byType(StatusCountTile), findsNWidgets(5));
  });

  testWidgets('la période filtre les comptes et les rubriques', (tester) async {
    await _ouvrir(tester, AppRoutes.clientOrders);

    await _toucher(tester, find.byTooltip('Filtrer par période'));
    await _toucher(tester, find.text('30 derniers jours'));
    await _toucher(tester, find.text('Terminé'));

    expect(find.text('Sur les 30 derniers jours'), findsOneWidget);
    // L'annulée date de 60 jours : hors période.
    expect(_compte(tester, 'Annulées'), '0');
    expect(_compte(tester, 'Livrées'), '1');

    await _toucher(tester, find.text('Annulées'));
    expect(
      find.text('Aucune commande annulée sur les 30 derniers jours'),
      findsOneWidget,
    );

    // De retour sur l'historique, la période tient toujours.
    await tester.pageBack();
    await _avancer(tester);
    expect(_compte(tester, 'Annulées'), '0');

    await _toucher(tester, find.byTooltip('Filtrer par période'));
    await _toucher(tester, find.text('Tout effacer'));
    await _toucher(tester, find.text('Terminé'));
    expect(_compte(tester, 'Annulées'), '1');
    expect(find.text('Sur les 30 derniers jours'), findsNothing);
  });

  testWidgets('une commande livrée : avis, livreur, code promo, paiement', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.orderDetail(commandeLivree.id));

    expect(find.text('Payé · Orange Money'), findsOneWidget);
    expect(find.text('Code BOGOLAN10'), findsOneWidget);
    // Une part à noter, l'autre déjà notée.
    expect(find.text('Laisser un avis'), findsOneWidget);
    expect(find.text('Avis publié. Merci !'), findsOneWidget);
    // Seule la part livrée par MTC a un livreur.
    expect(find.text('Noter le livreur'), findsOneWidget);
    expect(find.text('Annuler la commande'), findsNothing);
    expect(find.text('Suivre la livraison'), findsNothing);
    expect(find.text('Code de remise'), findsNothing);

    await _toucher(tester, find.text('Laisser un avis'));
    expect(find.text('AVIS g-bogolan'), findsOneWidget);
  });

  testWidgets('une commande en route : suivi, QR de remise, message entier', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.orderDetail(commandeEnRoute.id));

    expect(find.text('Code de remise'), findsOneWidget);
    expect(find.text('Message pour la boutique'), findsOneWidget);
    expect(
      find.text('Appelez-moi en arrivant, le portail bleu est fermé à clé.'),
      findsOneWidget,
    );
    expect(find.text('À payer à la livraison'), findsOneWidget);
    // La part de Kita, encore en préparation, n'a ni suivi ni annulation.
    expect(find.text('Suivre la livraison'), findsOneWidget);
    expect(find.text('Annuler la commande'), findsNothing);

    await _toucher(tester, find.text('Suivre la livraison'));
    expect(find.text('SUIVI'), findsOneWidget);
  });

  testWidgets('une commande annulée par la boutique dit qui et pourquoi', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.orderDetail(commandeAnnulee.id));

    expect(find.text('Point de livraison'), findsOneWidget);
    expect(
      find.text(
        'Annulée par le fournisseur : Rupture de stock chez notre fournisseur.',
      ),
      findsOneWidget,
    );
    expect(find.text('Annuler la commande'), findsNothing);
    // Rien ne sera livré : ni montant dû, ni « à payer à la livraison ».
    expect(find.text('Rien à régler'), findsOneWidget);
    expect(find.text('À payer à la livraison'), findsNothing);
    expect(find.text('Commande annulée'), findsOneWidget);
    expect(
      find.text('-${CurrencyFormatter.formatFcfa(48000)}'),
      findsOneWidget,
    );
    expect(find.text(CurrencyFormatter.formatFcfa(0)), findsOneWidget);
  });

  testWidgets('une part annulée sort du total, les autres restent dues', (
    tester,
  ) async {
    final partielle = commande(
      id: 'c0ffee00-1111-4222-8333-444455556666',
      statut: OrderStatus.inTransit,
      passeeLe: DateTime.now().subtract(const Duration(days: 2)),
      groupes: [
        groupe(
          'g-panneau',
          'MTC Officiel',
          [article('panneau', 1, prix: 55250)],
          statut: OrderStatus.inTransit,
          frais: 2000,
        ),
        groupe(
          'g-kita',
          'Coopérative de Kita',
          [article('miel', 3)],
          statut: OrderStatus.cancelled,
          mode: DeliveryMode.selfDelivery,
          frais: 1000,
          motif: 'Je n\'en ai plus besoin',
          annuleePar: CancelledBy.client,
        ),
      ],
    );
    expect(partielle.totalFcfa, 71750);
    await _ouvrir(
      tester,
      AppRoutes.orderDetail(partielle.id),
      commandes: [partielle],
    );

    expect(
      find.text('Annulée par le client : Je n\'en ai plus besoin'),
      findsOneWidget,
    );
    expect(find.text('À payer à la livraison'), findsOneWidget);
    expect(find.text('Parts annulées'), findsOneWidget);
    // Le miel (3 × 4 500) et sa livraison (1 000).
    expect(
      find.text('-${CurrencyFormatter.formatFcfa(14500)}'),
      findsOneWidget,
    );
    expect(find.text(CurrencyFormatter.formatFcfa(57250)), findsOneWidget);
  });

  testWidgets('annuler demande une raison, l\'envoie et le confirme', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.orderDetail(commandeEnAttente.id));
    // Le QR n'apparaît qu'une fois le colis retiré : ici, la course est
    // seulement proposée aux livreurs.
    expect(find.text('Code de remise'), findsNothing);
    expect(find.text('Commande prioritaire'), findsOneWidget);

    await _toucher(tester, find.text('Annuler la commande'));
    expect(find.text('Pourquoi voulez-vous annuler ?'), findsOneWidget);
    expect(_barre(tester).onPressed, isNull);

    await _toucher(tester, find.text('Autre raison'));
    await tester.enterText(find.byType(TextField), '  Je passe la prendre  ');
    await tester.pump();
    expect(_barre(tester).onPressed, isNotNull);

    await _toucher(tester, find.byType(BottomActionBar));

    expect(_depot.annulations, hasLength(1));
    final envoi = _depot.annulations.single;
    expect(envoi[#orderId], commandeEnAttente.id);
    expect(envoi[#groupId], 'g-riz');
    expect(envoi[#status], OrderStatus.cancelled);
    expect(envoi[#cancelledBy], CancelledBy.client);
    expect(envoi[#cancellationReason], 'Je passe la prendre');

    // Revenu sur la fiche, avec la confirmation.
    expect(find.text('Pourquoi voulez-vous annuler ?'), findsNothing);
    expect(
      find.text('Votre commande chez Grenier du Mali est annulée.'),
      findsWidgets,
    );
  });

  testWidgets('une raison de la liste part telle quelle', (tester) async {
    await _ouvrir(tester, AppRoutes.orderCancel(commandeEnAttente.id, 'g-riz'));

    await _toucher(tester, find.text('Je n\'en ai plus besoin'));
    await _toucher(tester, find.byType(BottomActionBar));

    expect(
      _depot.annulations.single[#cancellationReason],
      'Je n\'en ai plus besoin',
    );
    // Ouvert seul, l'écran ne laisse pas une pile vide : il mène à la fiche.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Commande #2D9A6C0E'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('un refus du serveur est dit, et l\'écran reste', (tester) async {
    await _ouvrir(tester, AppRoutes.orderCancel(commandeEnAttente.id, 'g-riz'));
    _depot.refus = const PostgrestException(
      message: 'La boutique vient de confirmer cette commande.',
      code: 'P0001',
    );

    await _toucher(tester, find.text('Je n\'en ai plus besoin'));
    await _toucher(tester, find.byType(BottomActionBar));

    expect(
      find.text('La boutique vient de confirmer cette commande.'),
      findsOneWidget,
    );
    expect(find.text('Pourquoi voulez-vous annuler ?'), findsOneWidget);
  });

  testWidgets('une part déjà confirmée ne s\'annule plus d\'ici', (
    tester,
  ) async {
    await _ouvrir(tester, AppRoutes.orderCancel(commandeEnRoute.id, 'g-kita'));

    expect(
      find.textContaining('a déjà confirmé cette commande'),
      findsOneWidget,
    );
    expect(find.byType(BottomActionBar), findsNothing);
    expect(find.text('Pourquoi voulez-vous annuler ?'), findsNothing);
  });

  testWidgets('le « i » explique quand on peut annuler', (tester) async {
    await _ouvrir(tester, AppRoutes.orderCancel(commandeEnAttente.id, 'g-riz'));

    await _toucher(tester, find.byTooltip('Quand annuler ?'));
    expect(
      find.textContaining('tant que la boutique n\'a pas confirmé'),
      findsOneWidget,
    );
    await _toucher(tester, find.text('Compris'));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
