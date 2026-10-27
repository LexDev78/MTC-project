import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/ratings/domain/repositories/review_repository.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/ratings/presentation/screens/submit_review_screen.dart';
import 'package:mtc_app/features/ratings/presentation/widgets/review_entry.dart';

/// Le serveur des avis, réduit à ce que le parcours touche.
class _Avis implements ReviewRepository {
  final envoyes = <String>[];

  /// La part notée et ses étoiles, à chaque envoi.
  final parts = <(String, int)>[];

  /// Le titre de chaque envoi, `null` quand il n'y en a pas.
  final titres = <String?>[];

  /// Si posée, l'envoi échoue avec elle.
  Object? refus;

  @override
  Future<void> submitReview({
    required String orderId,
    required String supplierGroupId,
    required int stars,
    required String comment,
    List<String> imagePaths = const [],
    String? videoPath,
    String? title,
  }) async {
    if (refus != null) throw refus!;
    envoyes.add(comment);
    parts.add((supplierGroupId, stars));
    titres.add(title);
  }

  @override
  Future<bool> canReview({
    required String orderId,
    required String supplierGroupId,
  }) async => !parts.any((p) => p.$1 == supplierGroupId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _commande = Order(
  id: 'cmd-1',
  clientId: 'client-1',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierGroups: const [
    OrderSupplierGroup(
      id: 'g1',
      supplierId: 'f1',
      supplierName: 'Bogolan Bamako',
      items: [],
      deliveryMode: DeliveryMode.mtcDelivery,
      deliveryFeeFcfa: 1000,
      subtotalFcfa: 15000,
      status: OrderStatus.delivered,
    ),
  ],
  status: OrderStatus.delivered,
  placedAt: DateTime(2026, 10, 18, 7, 51),
  totalFcfa: 16000,
  deliveryCity: 'Bamako',
  clientContact: const OrderContact(
    phone: '70000000',
    addressLabel: 'Maison',
    addressDetails: 'Badalabougou',
    latitude: 12.63,
    longitude: -8.0,
  ),
);

OrderSupplierGroup _part(
  String id,
  String boutique,
  List<String> articles, {
  OrderStatus statut = OrderStatus.delivered,
}) => OrderSupplierGroup(
  id: id,
  supplierId: 'f-$id',
  supplierName: boutique,
  items: [
    for (final nom in articles)
      OrderItem(
        productId: 'p-$nom',
        productNameSnapshot: nom,
        unitPriceFcfaSnapshot: 5000,
        quantity: 1,
      ),
  ],
  deliveryMode: DeliveryMode.selfDelivery,
  deliveryFeeFcfa: 0,
  subtotalFcfa: 5000 * articles.length,
  status: statut,
);

/// Une commande livrée par deux boutiques, et une troisième encore en route.
final _troisBoutiques = _commande.copyWith(
  id: 'cmd-2',
  supplierGroups: [
    _part('g-a', 'Bogolan Bamako', ['Tissu bogolan']),
    _part('g-b', 'Atelier de Mopti', ['Masque dogon', 'Panier tressé']),
    _part('g-c', 'Grenier du Mali', ['Riz'], statut: OrderStatus.inTransit),
  ],
);

/// Les deux champs du formulaire, par ce qu'ils invitent à écrire.
final _champCommentaire = find.widgetWithText(
  TextFormField,
  'Ce que les prochains acheteurs devraient savoir',
);
final _champTitre = find.widgetWithText(
  TextFormField,
  'Résumez votre avis (facultatif)',
);

// Demandé le 18/10/2026 : « quand le client laisse un avis il doit voir la
// confirmation que l'avis a été laissé ». L'écran se fermait sans un mot,
// et la commande gardait son bouton « Laisser un avis ».
void main() {
  late _Avis avis;

  Future<void> laisserUnAvis(WidgetTester tester) async {
    avis = _Avis();
    final router = GoRouter(
      initialLocation: '/client/orders/cmd-1',
      routes: [
        GoRoute(
          path: '/client/orders/:id',
          builder: (_, _) => const Scaffold(
            body: Center(
              child: ReviewEntry(orderId: 'cmd-1', groupId: 'g1'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'review',
              builder: (_, state) => SubmitReviewScreen(
                orderId: state.pathParameters['id']!,
                groupId: state.uri.queryParameters['group'],
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(avis),
          orderDetailProvider(
            'cmd-1',
          ).overrideWith((ref) => Stream.value(_commande)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Laisser un avis'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 étoiles'));
    await tester.pumpAndSettle();
    await tester.enterText(_champCommentaire, 'Tissu magnifique');
  }

  testWidgets('l\'avis envoyé est confirmé, et la commande le montre publié', (
    tester,
  ) async {
    await laisserUnAvis(tester);

    await tester.tap(find.text('Envoyer l\'avis'));
    await tester.pumpAndSettle();

    expect(avis.envoyes, ['Tissu magnifique']);
    expect(avis.parts, [('g1', 5)]);
    // Sans titre saisi, aucun ne part.
    expect(avis.titres, [null]);
    expect(find.text('Merci ! Votre avis est publié.'), findsOneWidget);
    expect(find.text('Avis publié. Merci !'), findsOneWidget);
    expect(find.text('Laisser un avis'), findsNothing);
  });

  testWidgets('un refus dit pourquoi, et l\'avis reste à l\'écran', (
    tester,
  ) async {
    await laisserUnAvis(tester);
    avis.refus = const PostgrestException(
      message: 'Vous avez déjà noté cette commande.',
      code: 'P0001',
    );

    await tester.tap(find.text('Envoyer l\'avis'));
    await tester.pumpAndSettle();

    expect(find.text('Vous avez déjà noté cette commande.'), findsOneWidget);
    // Toujours sur le formulaire : le texte saisi n'est pas perdu.
    expect(find.text('Tissu magnifique'), findsOneWidget);
  });

  group('une commande livrée par plusieurs boutiques', () {
    Future<void> ouvrir(WidgetTester tester, String groupe) async {
      avis = _Avis();
      final router = GoRouter(
        initialLocation: '/client/orders/cmd-2/review?group=$groupe',
        routes: [
          GoRoute(
            path: '/client/orders/:id',
            builder: (_, _) => const Scaffold(body: Text('COMMANDE')),
            routes: [
              GoRoute(
                path: 'review',
                builder: (_, state) => SubmitReviewScreen(
                  orderId: state.pathParameters['id']!,
                  groupId: state.uri.queryParameters['group'],
                ),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(avis),
            orderDetailProvider(
              'cmd-2',
            ).overrideWith((ref) => Stream.value(_troisBoutiques)),
            // Les photos des articles ne comptent pas ici.
            productDetailProvider.overrideWith(
              (ref, id) => Completer<Product>().future,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> toucher(WidgetTester tester, Finder cible) async {
      await tester.ensureVisible(cible);
      await tester.pump();
      await tester.tap(cible);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('l\'avis porte sur la part choisie, pas sur la première', (
      tester,
    ) async {
      await ouvrir(tester, 'g-b');

      expect(find.text('ATELIER DE MOPTI'), findsOneWidget);
      expect(find.text('Masque dogon'), findsOneWidget);
      expect(find.text('et 1 autre article'), findsOneWidget);

      await toucher(tester, find.byTooltip('4 étoiles'));
      await tester.enterText(_champCommentaire, 'Masque superbe');
      await toucher(tester, find.text('Envoyer l\'avis'));

      expect(avis.parts, [('g-b', 4)]);
      expect(find.text('COMMANDE'), findsOneWidget);
    });

    testWidgets('sans étoile, l\'avis ne part pas et l\'écran dit pourquoi', (
      tester,
    ) async {
      await ouvrir(tester, 'g-a');
      await tester.enterText(_champCommentaire, 'Beau tissu');

      await toucher(tester, find.text('Envoyer l\'avis'));
      expect(
        find.text('Choisissez une note de 1 à 5 étoiles.'),
        findsOneWidget,
      );
      expect(avis.parts, isEmpty);

      await toucher(tester, find.byTooltip('3 étoiles'));
      expect(find.text('Choisissez une note de 1 à 5 étoiles.'), findsNothing);
      await toucher(tester, find.text('Envoyer l\'avis'));
      expect(avis.parts, [('g-a', 3)]);
    });

    testWidgets('le titre part avec l\'avis, et le compte suit la saisie', (
      tester,
    ) async {
      await ouvrir(tester, 'g-a');
      expect(find.text('100 caractères restants'), findsOneWidget);

      await tester.enterText(_champTitre, '  Superbe  ');
      await tester.pump();
      // Le compte porte sur la saisie telle quelle, blancs compris.
      expect(find.text('89 caractères restants'), findsOneWidget);

      await toucher(tester, find.byTooltip('5 étoiles'));
      await tester.enterText(_champCommentaire, 'Tissu épais et beau');
      await toucher(tester, find.text('Envoyer l\'avis'));

      expect(avis.titres, ['Superbe']);
      expect(avis.parts, [('g-a', 5)]);
    });

    testWidgets('une part encore en route ne se note pas', (tester) async {
      await ouvrir(tester, 'g-c');

      expect(find.text('Pas encore livrée'), findsOneWidget);
      expect(find.text('Envoyer l\'avis'), findsNothing);
    });
  });
}
