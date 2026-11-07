import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/favorites/domain/entities/favorite.dart';
import 'package:mtc_app/features/favorites/domain/repositories/favorite_repository.dart';
import 'package:mtc_app/features/favorites/presentation/providers/favorite_providers.dart';
import 'package:mtc_app/features/favorites/presentation/screens/favorites_screen.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../support/shop_fixtures.dart';

/// Les favoris du kit, sans base : des favoris tenus en mémoire et diffusés
/// comme la base le ferait, un catalogue de démonstration, un panier qui
/// note ses ajouts.

class _Favoris implements FavoriteRepository {
  _Favoris(Iterable<String> ids) : _ids = [...ids];

  final List<String> _ids;
  final _flux = StreamController<List<Favorite>>.broadcast();

  List<Favorite> get _liste => [
    for (final id in _ids)
      Favorite(
        id: 'fav-$id',
        userId: 'client-awa',
        productId: id,
        createdAt: DateTime(2026),
      ),
  ];

  @override
  Stream<List<Favorite>> watchForUser(String userId) async* {
    yield _liste;
    yield* _flux.stream;
  }

  @override
  Future<void> addFavorite({
    required String userId,
    required String productId,
  }) async {
    _ids.add(productId);
    _flux.add(_liste);
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    _ids.remove(productId);
    _flux.add(_liste);
  }
}

class _Produits implements ProductRepository {
  /// Comme la vraie lecture de liste : `hasVariants` est là, les variantes
  /// non (voir `fetchByIds`).
  @override
  Future<List<Product>> fetchByIds(List<String> ids) async => [
    for (final id in ids)
      if (id == 'bogolan')
        bogolanAVariantes().copyWith(variants: [], characteristics: [])
      else if (catalogueDemo().where((p) => p.id == id).firstOrNull
          case final p?)
        p,
  ];

  @override
  Future<Product> getById(String id) async => bogolanAVariantes();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Panier implements CartRepository {
  final ajouts = <({String produit, String? variante})>[];

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
    ajouts.add((produit: productId, variante: variantId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recommandations implements RecommendationRepository {
  @override
  Future<void> logCartAdd(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Favoris _favoris;
late _Panier _panier;

Future<void> _ouvrir(WidgetTester tester, List<String> ids) async {
  tester.view.physicalSize = const Size(375, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _favoris = _Favoris(ids);
  _panier = _Panier();
  final conteneur = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      favoriteRepositoryProvider.overrideWithValue(_favoris),
      productRepositoryProvider.overrideWithValue(_Produits()),
      cartRepositoryProvider.overrideWithValue(_panier),
      recommendationRepositoryProvider.overrideWithValue(_Recommandations()),
    ],
  );
  addTearDown(conteneur.dispose);
  conteneur.listen(currentUserProvider, (_, _) {});

  final router = GoRouter(
    initialLocation: '/client/favorites',
    routes: [
      GoRoute(
        path: '/client/favorites',
        builder: (context, state) => const ShopScope(child: FavoritesScreen()),
      ),
      GoRoute(
        path: '/client/product/:productId',
        builder: (context, state) =>
            Scaffold(body: Text('FICHE ${state.pathParameters['productId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _carte(String titre) => find.ancestor(
  of: find.text(titre),
  matching: find.byType(ShopProductCard),
);

void main() {
  testWidgets('la grille montre les favoris, et une carte ouvre sa fiche', (
    tester,
  ) async {
    await _ouvrir(tester, ['miel', 'radio']);
    expect(find.text('2 articles'), findsOneWidget);
    expect(find.byType(ShopProductCard), findsNWidgets(2));

    await tester.tap(_carte('Miel pur de Kita'));
    await _avancer(tester);
    expect(find.text('FICHE miel'), findsOneWidget);
  });

  testWidgets('retirer en lot, puis annuler, remet les favoris', (
    tester,
  ) async {
    await _ouvrir(tester, ['miel', 'radio', 'riz']);
    await tester.tap(find.text('Choisir'));
    await _avancer(tester);
    // En sélection, toucher une carte la coche au lieu de l'ouvrir.
    await tester.tap(_carte('Miel pur de Kita'));
    await tester.tap(_carte('Radio FM solaire'));
    await _avancer(tester);
    expect(find.text('2 articles choisis'), findsOneWidget);
    expect(find.textContaining('FICHE'), findsNothing);

    await tester.tap(find.text('Retirer'));
    await _avancer(tester);
    expect(find.byType(ShopProductCard), findsOneWidget);
    expect(find.text('2 articles retirés des favoris.'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await _avancer(tester);
    expect(find.byType(ShopProductCard), findsNWidgets(3));
  });

  testWidgets(
    'ajouter au panier en lot relit les variantes, puis confirme',
    (tester) async {
      await _ouvrir(tester, ['bogolan', 'miel']);
      await tester.tap(find.text('Choisir'));
      await _avancer(tester);
      await tester.tap(find.text('Tout'));
      await _avancer(tester);
      await tester.tap(find.text('Au panier'));
      await _avancer(tester);

      // Le bogolan a des variantes : relu en entier, il part avec sa
      // variante par défaut ; le miel, sans variante, tel quel.
      expect(_panier.ajouts, [
        (produit: 'bogolan', variante: 'v-indigo-2'),
        (produit: 'miel', variante: null),
      ]);
      expect(find.text('Ajouté au panier'), findsOneWidget);
    },
  );

  testWidgets('sans favori, l\'écran dit comment en ajouter', (tester) async {
    await _ouvrir(tester, []);
    expect(find.text('Aucun favori'), findsOneWidget);
    expect(find.text('Choisir'), findsNothing);
  });
}
