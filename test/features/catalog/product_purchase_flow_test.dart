import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/favorites/presentation/providers/favorite_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/ratings/domain/entities/product_review.dart';
import 'package:mtc_app/features/ratings/domain/entities/review_sort.dart';
import 'package:mtc_app/features/ratings/domain/repositories/review_repository.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/ratings/presentation/screens/product_reviews_screen.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../support/shop_fixtures.dart';

/// La fiche produit du kit, parcourue de bout en bout sans base : le choix
/// d'une variante, l'ajout au panier, l'achat immédiat, puis l'écran des
/// avis. Les dépôts sont remplacés par des doublures qui notent ce qu'on
/// leur demande.

class _Produits implements ProductRepository {
  @override
  Future<void> incrementViewCount(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recommandations implements RecommendationRepository {
  @override
  Future<void> logProductView(String productId) async {}

  @override
  Future<void> logCartAdd(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Panier implements CartRepository {
  final ajouts = <({String? variante, String? nom, int quantite, int prix})>[];

  /// Si posée, l'ajout échoue avec elle.
  Object? refus;

  @override
  Future<void> addItem({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    int quantity = 1,
    String? variantId,
    String? variantName,
  }) async {
    if (refus != null) throw refus!;
    ajouts.add((
      variante: variantId,
      nom: variantName,
      quantite: quantity,
      prix: unitPriceFcfa,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Avis implements ReviewRepository {
  final demandes = <({ReviewSort tri, int decalage})>[];

  /// Le nombre d'avis que le produit a en tout.
  int total = 3;

  @override
  Future<List<ProductReview>> fetchProductReviews({
    required String productId,
    int limit = 20,
    int offset = 0,
    ReviewSort sort = ReviewSort.recent,
  }) async {
    demandes.add((tri: sort, decalage: offset));
    final modele = avisDemo();
    final restants = (total - offset).clamp(0, limit);
    return [
      for (var i = 0; i < restants; i++)
        modele[i % modele.length].copyWith(id: 'avis-${offset + i}'),
    ];
  }

  @override
  Future<ProductReviewSummary> fetchProductReviewSummary(
    String productId,
  ) async => ProductReviewSummary(reviewCount: total, ratingAverage: 4);

  @override
  Future<Map<int, int>> fetchProductRatingDistribution(
    String productId,
  ) async => {5: 1, 4: 1, 3: total - 2};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Order _commandeLivree(String produitId) => Order(
  id: 'cmd-1',
  clientId: 'client-awa',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierGroups: [
    OrderSupplierGroup(
      id: 'g1',
      supplierId: 'f-Bogolan Bamako',
      supplierName: 'Bogolan Bamako',
      items: [
        OrderItem(
          productId: produitId,
          productNameSnapshot: 'Tissu bogolan traditionnel',
          unitPriceFcfaSnapshot: 15000,
          quantity: 1,
        ),
      ],
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

late _Panier _panier;
late _Avis _avis;
late ProviderContainer _conteneur;

/// Monte l'app réduite à la fiche et à ses destinations, sur [depart].
Future<void> _ouvrir(
  WidgetTester tester, {
  Product? produit,
  List<Order> commandes = const [],
  String depart = '/client/product/bogolan',
}) async {
  // Un écran haut : la feuille d'achat y tient entière, et l'on vérifie le
  // parcours plutôt que le défilement (les rendus `test/visual/` regardent,
  // eux, la taille d'un téléphone).
  tester.view.physicalSize = const Size(375, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final p = produit ?? bogolanAVariantes();
  _panier = _Panier();
  _avis = _Avis();
  _conteneur = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      productDetailProvider(p.id).overrideWith((ref) async => p),
      productRepositoryProvider.overrideWithValue(_Produits()),
      recommendationRepositoryProvider.overrideWithValue(_Recommandations()),
      cartRepositoryProvider.overrideWithValue(_panier),
      reviewRepositoryProvider.overrideWithValue(_avis),
      favoriteProductIdsProvider.overrideWith((ref) => Stream.value(const {})),
      productCommentsProvider(p.id).overrideWith((ref) => Stream.value([])),
      similarProductsProvider(p).overrideWith((ref) => Stream.value([])),
      ordersForUserProvider.overrideWith((ref) => Stream.value(commandes)),
    ],
  );
  addTearDown(_conteneur.dispose);
  // Dans l'app, le compte est toujours écouté (le routeur, la session) : la
  // feuille le lit sans l'écouter, il doit donc être déjà là.
  _conteneur.listen(currentUserProvider, (_, _) {});

  final router = GoRouter(
    initialLocation: depart,
    routes: [
      GoRoute(
        path: '/client/product/:productId',
        builder: (context, state) => ShopScope(
          child: ProductDetailScreen(
            productId: state.pathParameters['productId']!,
          ),
        ),
        routes: [
          GoRoute(
            path: 'reviews',
            builder: (context, state) => ShopScope(
              child: ProductReviewsScreen(
                productId: state.pathParameters['productId']!,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) => const Scaffold(body: Text('PAIEMENT')),
      ),
      GoRoute(
        path: '/client/home',
        builder: (context, state) => const Scaffold(body: Text('ACCUEIL')),
      ),
      GoRoute(
        path: '/client/orders/:orderId/review',
        builder: (context, state) =>
            Scaffold(body: Text('NOTER ${state.pathParameters['orderId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
}

/// Laisse passer les chargements et les animations de feuille, sans
/// `pumpAndSettle` (les images se décodent hors de l'horloge du test).
Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Fait défiler la liste verticale du dessus (la feuille quand elle est
/// ouverte) jusqu'à [cible] : sous le pli, une liste ne construit pas ses
/// éléments, et le chercheur ne les trouverait pas.
Future<void> _amener(WidgetTester tester, Finder cible) async {
  if (cible.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      cible,
      300,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await tester.ensureVisible(cible);
  await tester.pump();
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await _amener(tester, cible);
  await tester.tap(cible);
  await _avancer(tester);
}

/// Le bouton du bas de la feuille d'achat (celui de la fiche est dessous).
CartButton _boutonDeLaFeuille(WidgetTester tester) =>
    tester.widget<CartButton>(find.byType(CartButton).last);

void main() {
  testWidgets(
    'une variante qui regroupe deux longueurs attend qu\'on en choisisse une, '
    'et seule celle-là part au panier',
    (tester) async {
      // « Ocre » par défaut : vendue en 2 m et 3 m ensemble, rien n'est
      // encore tranché.
      final p = bogolanAVariantes();
      await _ouvrir(
        tester,
        produit: p.copyWith(
          variants: [
            for (final v in p.variants) v.copyWith(isDefault: v.id == 'v-ocre'),
          ],
        ),
      );

      // Le prix de la variante par défaut, remise comprise.
      expect(find.text(CurrencyFormatter.formatFcfa(12800)), findsOneWidget);
      await _toucher(tester, find.text('Acheter'));
      expect(find.text('8 en stock'), findsOneWidget);
      expect(find.text('Choisissez une valeur.'), findsOneWidget);
      expect(find.text('Choisir : longueur'), findsOneWidget);
      expect(_boutonDeLaFeuille(tester).onPressed, isNull);

      await _toucher(tester, find.text('3 m'));
      expect(find.text('Choisissez une valeur.'), findsNothing);
      expect(find.text('Ajouter au panier'), findsOneWidget);
      expect(_boutonDeLaFeuille(tester).onPressed, isNotNull);

      await _toucher(tester, find.text('Ajouter au panier'));
      expect(_panier.ajouts, hasLength(1));
      // Le nom réduit au choix du client, pas « Ocre 2 m 3 m ».
      expect(_panier.ajouts.single.nom, 'Ocre 3 m');
      expect(_panier.ajouts.single.variante, 'v-ocre');
      expect(_panier.ajouts.single.quantite, 1);
      expect(find.text('Ajouté au panier'), findsOneWidget);

      // « Commander » paie le panier entier, pas un achat immédiat oublié.
      await _toucher(tester, find.text('Commander'));
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(_conteneur.read(buyNowItemProvider), isNull);
    },
  );

  testWidgets(
    'changer de couleur garde la longueur déjà choisie quand la nouvelle '
    'couleur l\'a aussi',
    (tester) async {
      await _ouvrir(tester);
      expect(find.text(CurrencyFormatter.formatFcfa(12000)), findsOneWidget);
      await _toucher(tester, find.text('Acheter'));
      expect(find.text('12 en stock'), findsOneWidget);

      // Indigo 2 m → Ocre : la 2 m existe en ocre, elle reste choisie.
      await _toucher(tester, find.text('Ocre'));
      expect(find.text('8 en stock'), findsOneWidget);
      expect(find.text('Choisissez une valeur.'), findsNothing);

      await _toucher(tester, find.text('Ajouter au panier'));
      expect(_panier.ajouts.single.nom, 'Ocre 2 m');
    },
  );

  testWidgets(
    'l\'achat immédiat ne porte que cet article, à la variante choisie',
    (tester) async {
      await _ouvrir(tester);
      await _toucher(tester, find.text('Acheter'));

      await _toucher(tester, find.text('6 m'));
      expect(find.text('4 en stock'), findsOneWidget);

      await _toucher(tester, find.text('Acheter maintenant'));
      expect(find.text('PAIEMENT'), findsOneWidget);
      final achat = _conteneur.read(buyNowItemProvider);
      expect(achat, isNotNull);
      expect(achat!.variantNameSnapshot, 'Indigo 6 m');
      expect(achat.variantId, 'v-indigo-6');
      expect(achat.quantity, 1);
      expect(achat.unitPriceFcfaSnapshot, 39000);
      // Le panier, lui, n'a pas bougé.
      expect(_panier.ajouts, isEmpty);
    },
  );

  testWidgets(
    'la quantité s\'arrête au stock, et repart de 1 quand la variante change',
    (tester) async {
      await _ouvrir(tester);
      await _toucher(tester, find.text('Acheter'));
      await _toucher(tester, find.text('6 m'));

      for (var i = 0; i < 5; i++) {
        await _toucher(tester, find.byTooltip('Ajouter un'));
      }
      // Stock de 4 : le cinquième toucher n'a rien fait. À 4, c'est la
      // remise de 20 % qui joue (celle de 30 % commence à 5).
      expect(_boutonDeLaFeuille(tester).priceFcfa, 4 * 31200);
      expect(find.textContaining('Encore 1 unité pour'), findsOneWidget);

      await _toucher(tester, find.text('2 m'));
      expect(find.text('12 en stock'), findsOneWidget);
      expect(_boutonDeLaFeuille(tester).priceFcfa, 12000);
    },
  );

  testWidgets(
    'un ajout refusé le dit, et rien ne se dit « ajouté »',
    (tester) async {
      await _ouvrir(tester);
      _panier.refus = StateError('panne simulée');
      await _toucher(tester, find.text('Acheter'));
      await _toucher(tester, find.text('Ajouter au panier'));

      expect(find.text('Ajouté au panier'), findsNothing);
      // Affiché dans la feuille comme sous elle : un `SnackBar` par
      // `Scaffold`.
      expect(
        find.text('L\'article n\'a pas pu être ajouté au panier.'),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'en rupture, la fiche propose d\'écrire à la boutique au lieu d\'acheter',
    (tester) async {
      await _ouvrir(
        tester,
        produit: bogolanAVariantes().copyWith(stockQuantity: 0),
      );
      expect(find.byType(CartButton), findsNothing);
      expect(find.byType(NoticeCard), findsOneWidget);
      expect(find.text('Rupture de stock'), findsOneWidget);
    },
  );

  testWidgets(
    'le tri des avis est demandé à la base, et la suite se charge par pages',
    (tester) async {
      await _ouvrir(tester, depart: '/client/product/bogolan/reviews');
      _avis.total = 23;
      _conteneur.invalidate(productReviewsPageProvider);
      await _avancer(tester);
      expect(_avis.demandes.last, (tri: ReviewSort.recent, decalage: 0));

      await _toucher(tester, find.text('Plus récents'));
      await _toucher(
        tester,
        find.descendant(
          of: find.byType(ShopRadioTile<ReviewSort>),
          matching: find.text('Mieux notés'),
        ),
      );
      expect(_avis.demandes.last, (tri: ReviewSort.best, decalage: 0));
      expect(find.text('Mieux notés'), findsOneWidget);

      // Vingt avis, une page pleine : il y en a peut-être d'autres.
      await _toucher(tester, find.text('Voir plus d\'avis'));
      expect(_avis.demandes.last, (tri: ReviewSort.best, decalage: 20));
      // Trois de plus, et c'est la fin.
      expect(find.text('Voir plus d\'avis'), findsNothing);
    },
  );

  testWidgets(
    '« Donner mon avis » ouvre la commande livrée, ou dit pourquoi il n\'y en '
    'a pas',
    (tester) async {
      await _ouvrir(tester, depart: '/client/product/bogolan/reviews');
      await _toucher(tester, find.text('Donner mon avis'));
      expect(
        find.text('Vous pourrez donner votre avis une fois ce produit livré.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('« Donner mon avis » mène à la commande qui a livré le produit', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      depart: '/client/product/bogolan/reviews',
      commandes: [_commandeLivree('bogolan')],
    );
    await _toucher(tester, find.text('Donner mon avis'));
    expect(find.text('NOTER cmd-1'), findsOneWidget);
  });
}
