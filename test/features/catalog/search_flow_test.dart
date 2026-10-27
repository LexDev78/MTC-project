import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_history_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_screen.dart';
import 'package:mtc_app/features/recommendations/domain/entities/recent_search.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../../support/shop_fixtures.dart';

/// La recherche du kit, sans base : ce qui est noté, relancé, effacé, et ce
/// que les filtres font des résultats.

class _Produits implements ProductRepository {
  final requetes = <String?>[];

  @override
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  }) {
    requetes.add(query);
    return Stream.value([
      for (final p in _catalogue)
        if (query == null || matchesAnySearch([p.name, p.supplierName], query))
          p,
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le journal des recherches, tenu en mémoire comme la base le tiendrait.
class _Journal implements RecommendationRepository {
  final notees = <String>[];
  final effacements = <String?>[];
  final historique = <RecentSearch>[];

  @override
  Future<void> logSearch(String query) async {
    notees.add(query);
    historique.removeWhere(
      (r) => normalizeForSearch(r.query) == normalizeForSearch(query),
    );
    historique.insert(0, (query: query, searchedAt: DateTime.now()));
  }

  @override
  Future<List<RecentSearch>> fetchRecentSearches({int limit = 30}) async =>
      historique.take(limit).toList();

  @override
  Future<int> forgetSearches({String? query}) async {
    effacements.add(query);
    final avant = historique.length;
    historique.removeWhere(
      (r) =>
          query == null ||
          normalizeForSearch(r.query) == normalizeForSearch(query),
    );
    return avant - historique.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Le catalogue de démonstration, plus une radio épuisée.
final _catalogue = [
  ...catalogueDemo(),
  produit(
    id: 'radio-epuisee',
    nom: 'Radio FM à manivelle',
    boutique: 'MTC Officiel',
    type: SupplierType.principal,
    photo: 'assets/images/products/electronique/radio_2.jpg',
    categorie: ProductCategory.electronique,
    prix: 9000,
    stock: 0,
  ),
];

late _Journal _journal;
late _Produits _produits;
late ProviderContainer _conteneur;

Future<void> _ouvrir(
  WidgetTester tester, {
  List<String> recentes = const [],
}) async {
  tester.view.physicalSize = const Size(375, 1400) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _journal = _Journal();
  _journal.historique.addAll([
    for (final (i, r) in recentes.indexed)
      (query: r, searchedAt: DateTime.now().subtract(Duration(hours: i))),
  ]);
  _produits = _Produits();
  _conteneur = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      productRepositoryProvider.overrideWithValue(_produits),
      recommendationRepositoryProvider.overrideWithValue(_journal),
    ],
  );
  addTearDown(_conteneur.dispose);

  final router = GoRouter(
    initialLocation: '/client/home',
    routes: [
      GoRoute(
        path: '/client/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/client/search'),
              child: const Text('OUVRIR LA RECHERCHE'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/client/search',
        builder: (context, state) => const ShopScope(child: SearchScreen()),
        routes: [
          GoRoute(
            path: 'history',
            builder: (context, state) =>
                const ShopScope(child: SearchHistoryScreen()),
          ),
          GoRoute(
            path: 'photo',
            builder: (context, state) =>
                const Scaffold(body: Text('PAR PHOTO')),
          ),
        ],
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
      container: _conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
  await tester.tap(find.text('OUVRIR LA RECHERCHE'));
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _taper(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(EditableText), texte);
  await _avancer(tester);
}

Future<void> _valider(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await _avancer(tester);
}

/// Les noms des cartes de la grille, dans l'ordre.
List<String> _cartes(WidgetTester tester) => [
  for (final carte in tester.widgetList<ShopProductCard>(
    find.byType(ShopProductCard),
  ))
    carte.data.title,
];

void main() {
  testWidgets(
    'une recherche validée est notée une fois, et ses résultats s\'affichent',
    (tester) async {
      await _ouvrir(tester);
      await _taper(tester, 'solaire');
      // Pendant la frappe : des suggestions, rien de noté.
      expect(find.text('Rechercher'), findsOneWidget);
      expect(_journal.notees, isEmpty);

      await _valider(tester);
      expect(_journal.notees, ['solaire']);
      expect(find.text('Résultats '), findsNothing);
      expect(find.textContaining('(2 articles)'), findsOneWidget);
      expect(
        _cartes(tester),
        containsAll(['Panneau solaire 100 W', 'Radio FM solaire']),
      );

      // Revalider le même texte ne le note pas deux fois.
      await _valider(tester);
      expect(_journal.notees, ['solaire']);
    },
  );

  testWidgets(
    'toucher une recherche récente la relance, résultats compris',
    (tester) async {
      await _ouvrir(tester, recentes: ['Miel', 'Bogolan']);
      expect(find.text('Recherches récentes'), findsOneWidget);
      expect(find.text('Miel'), findsOneWidget);

      await tester.tap(find.text('Bogolan'));
      await _avancer(tester);
      expect(_cartes(tester), ['Tissu bogolan traditionnel']);
      expect(find.textContaining('(1 article)'), findsOneWidget);
    },
  );

  testWidgets(
    'la croix efface la recherche du journal, et elle disparaît',
    (tester) async {
      await _ouvrir(tester, recentes: ['Miel', 'Bogolan']);
      await tester.tap(find.byTooltip('Effacer « Miel »'));
      await _avancer(tester);
      expect(_journal.effacements, ['Miel']);
      expect(find.text('Miel'), findsNothing);
      expect(find.text('Bogolan'), findsOneWidget);
    },
  );

  testWidgets(
    'l\'historique relance une recherche, et « Tout effacer » demande avant',
    (tester) async {
      await _ouvrir(tester, recentes: ['Riz', 'Miel']);
      await tester.tap(find.text('Tout voir'));
      await _avancer(tester);
      expect(find.text('Historique'), findsOneWidget);

      await tester.tap(find.text('Tout effacer'));
      await _avancer(tester);
      expect(find.text('Effacer l\'historique ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await _avancer(tester);
      expect(_journal.effacements, isEmpty);

      await tester.tap(find.text('Riz'));
      await _avancer(tester);
      // Revenu sur la recherche, relancée.
      expect(_cartes(tester), ['Riz local de l\'Office du Niger, 25 kg']);
    },
  );

  testWidgets('« Tout effacer » confirmé vide tout l\'historique', (
    tester,
  ) async {
    await _ouvrir(tester, recentes: ['Riz', 'Miel']);
    await tester.tap(find.text('Tout voir'));
    await _avancer(tester);
    await tester.tap(find.text('Tout effacer'));
    await _avancer(tester);
    await tester.tap(find.text('Effacer'));
    await _avancer(tester);
    expect(_journal.effacements, [null]);
    expect(find.text('Aucune recherche'), findsOneWidget);
  });

  testWidgets(
    'les filtres agissent sur les résultats : stock, puis tri par prix',
    (tester) async {
      await _ouvrir(tester);
      await _taper(tester, 'radio');
      await _valider(tester);
      expect(_cartes(tester), ['Radio FM solaire', 'Radio FM à manivelle']);

      await tester.tap(find.byTooltip('Filtrer et trier'));
      await _avancer(tester);
      await tester.tap(find.text('En stock uniquement'));
      await _avancer(tester);
      await tester.tap(find.text('Terminé'));
      await _avancer(tester);
      expect(_cartes(tester), ['Radio FM solaire']);

      await tester.tap(find.byTooltip('Filtrer et trier'));
      await _avancer(tester);
      // Le réglage déjà posé est repris.
      await tester.tap(find.text('Tout effacer'));
      await _avancer(tester);
      await tester.tap(find.text('Trier'));
      await _avancer(tester);
      await tester.tap(find.text('Prix croissant'));
      await _avancer(tester);
      await tester.tap(find.text('Terminé'));
      await _avancer(tester);
      expect(_cartes(tester), ['Radio FM à manivelle', 'Radio FM solaire']);
    },
  );

  testWidgets(
    'sans résultat, l\'écran propose la recherche par photo',
    (tester) async {
      await _ouvrir(tester);
      await _taper(tester, 'tracteur');
      await _valider(tester);
      expect(find.text('Aucun résultat'), findsOneWidget);
      await tester.tap(find.text('Rechercher par photo'));
      await _avancer(tester);
      expect(find.text('PAR PHOTO'), findsOneWidget);
    },
  );

  testWidgets('quitter avec un texte tapé le note quand même', (tester) async {
    await _ouvrir(tester);
    await _taper(tester, 'karité');
    await tester.tap(find.byTooltip('Fermer'));
    await _avancer(tester);
    expect(find.text('OUVRIR LA RECHERCHE'), findsOneWidget);
    expect(_journal.notees, ['karité']);
  });
}
