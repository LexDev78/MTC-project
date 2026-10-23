import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/suppliers/domain/entities/supplier_profile.dart';
import 'package:mtc_app/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/screens/shops_screen.dart';
import 'package:mtc_app/features/catalog/presentation/providers/home_catalog.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';
import 'package:mtc_app/root/presentation/client_home_screen.dart';

import '../../support/shop_fixtures.dart';

/// « Boutiques du Mali », sans base : l'ordre, la recherche, les villes, et
/// la vitrine au bout du doigt.

SupplierProfile _boutique(
  String id,
  String nom,
  String ville, {
  SupplierType type = SupplierType.tiers,
  double note = 4.5,
  int avis = 10,
  int produits = 4,
  bool ouverte = true,
}) => SupplierProfile(
  id: id,
  businessName: nom,
  supplierType: type,
  city: ville,
  ratingAverage: note,
  ratingCount: avis,
  // Le compteur de la boutique peut mentir (brouillons, saisie directe) :
  // l'écran lit le nombre que la base compte.
  productCount: 99,
  listedProductCount: produits,
  verificationStatus: type == SupplierType.tiers
      ? VerificationStatus.verified
      : null,
  isOpen: ouverte,
);

/// Dans le désordre, comme la base les rend (par nom).
final _boutiques = [
  _boutique('segou', 'Alimentation Ségou', 'Ségou', note: 4.8, avis: 210),
  _boutique('bogolan', 'Bogolan Bamako', 'Bamako', avis: 135),
  _boutique('electro', 'Electro Bamako', 'Bamako', avis: 54, ouverte: false),
  _boutique(
    'mtc',
    'MTC Officiel',
    'Bamako',
    type: SupplierType.principal,
    note: 4.9,
    avis: 340,
  ),
  _boutique('mopti', 'Tissus Mopti', 'Mopti', note: 5, avis: 1, produits: 1),
];

/// Le dépôt réduit à la lecture de la liste.
class _Boutiques implements SupplierRepository {
  _Boutiques(this.liste);

  List<SupplierProfile> liste;
  int lectures = 0;

  @override
  Future<List<SupplierProfile>> fetchListed() async {
    lectures++;
    return liste;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Boutiques _depot;

Future<void> _ouvrir(
  WidgetTester tester, {
  List<SupplierProfile>? boutiques,
}) async {
  tester.view.physicalSize = const Size(375, 1600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _depot = _Boutiques(boutiques ?? _boutiques);
  final router = GoRouter(
    initialLocation: AppRoutes.clientShops,
    routes: [
      GoRoute(
        path: AppRoutes.clientShops,
        builder: (_, _) => const ShopScope(child: ShopsScreen()),
      ),
      GoRoute(
        path: AppRoutes.clientSupplierProfile,
        builder: (_, state) => Scaffold(
          body: Text('VITRINE ${state.pathParameters['supplierId']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [supplierRepositoryProvider.overrideWithValue(_depot)],
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

/// Les noms des boutiques affichées, dans l'ordre de l'écran.
List<String> _noms(WidgetTester tester) => [
  for (final carte in tester.widgetList<ShopStoreCard>(
    find.byType(ShopStoreCard),
  ))
    carte.name,
];

void main() {
  testWidgets('MTC Officiel d\'abord, puis les plus suivies', (tester) async {
    await _ouvrir(tester);

    expect(_noms(tester), [
      'MTC Officiel',
      'Alimentation Ségou',
      'Bogolan Bamako',
      'Electro Bamako',
      // 5/5 sur un seul avis ne passe pas devant les autres.
      'Tissus Mopti',
    ]);
    expect(find.text('5 boutiques'), findsOneWidget);
  });

  testWidgets('chaque carte dit sa ville, ses produits, sa note, ses états', (
    tester,
  ) async {
    await _ouvrir(tester);

    expect(find.text('Ségou · 4 produits'), findsOneWidget);
    expect(find.text('Mopti · 1 produit'), findsOneWidget);
    expect(find.text('4,8 · 210 avis'), findsOneWidget);
    expect(find.text('MTC officiel'), findsOneWidget);
    expect(find.text('Identité vérifiée'), findsNWidgets(4));
    // Electro Bamako est fermée, les quatre autres ouvertes.
    expect(find.text('Fermée'), findsOneWidget);
    expect(find.text('Ouverte'), findsNWidgets(4));
  });

  testWidgets('la recherche ignore accents et majuscules, et lit la ville', (
    tester,
  ) async {
    await _ouvrir(tester);

    await tester.enterText(find.byType(TextField), 'SEGOU');
    await _avancer(tester);
    expect(_noms(tester), ['Alimentation Ségou']);
    expect(find.text('1 boutique'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mopti');
    await _avancer(tester);
    expect(_noms(tester), ['Tissus Mopti']);
  });

  testWidgets('une ville se choisit, et se rend d\'un second geste', (
    tester,
  ) async {
    await _ouvrir(tester);

    await tester.tap(find.widgetWithText(ShopPill, 'Bamako'));
    await _avancer(tester);
    expect(_noms(tester), ['MTC Officiel', 'Bogolan Bamako', 'Electro Bamako']);

    await tester.tap(find.widgetWithText(ShopPill, 'Bamako'));
    await _avancer(tester);
    expect(_noms(tester), hasLength(5));
  });

  testWidgets('rien ne correspond : le dire, et tout remettre d\'un geste', (
    tester,
  ) async {
    await _ouvrir(tester);

    await tester.enterText(find.byType(TextField), 'Tombouctou');
    await _avancer(tester);
    expect(find.text('Aucune boutique ne correspond'), findsOneWidget);
    expect(find.byType(ShopStoreCard), findsNothing);

    await tester.tap(find.text('Voir toutes les boutiques'));
    await _avancer(tester);
    expect(_noms(tester), hasLength(5));
    expect(find.text('Tombouctou'), findsNothing);
  });

  testWidgets('une boutique s\'ouvre sur sa vitrine', (tester) async {
    await _ouvrir(tester);

    await tester.tap(find.text('Bogolan Bamako'));
    await _avancer(tester);

    expect(find.text('VITRINE bogolan'), findsOneWidget);
  });

  testWidgets('sans boutique, l\'écran le dit au lieu de rester vide', (
    tester,
  ) async {
    await _ouvrir(tester, boutiques: const []);

    expect(find.text('Aucune boutique pour le moment'), findsOneWidget);
  });

  testWidgets('la bannière « Boutiques du Mali » de l\'accueil y mène', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 2300) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: AppRoutes.clientHome,
      routes: [
        GoRoute(
          path: AppRoutes.clientHome,
          builder: (_, _) => const ShopScope(child: ClientHomeScreen()),
        ),
        GoRoute(
          path: AppRoutes.clientShops,
          builder: (_, _) => const Scaffold(body: Text('PAGE BOUTIQUES')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeProductsProvider.overrideWith(
            (ref) => Stream.value(catalogueDemo()),
          ),
          recommendedFeedProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await _avancer(tester);

    // Le titre s'affiche en capitales ; le libellé du bas est unique.
    final banniere = find.text('VOIR LES BOUTIQUES');
    await tester.ensureVisible(banniere);
    await _avancer(tester);
    expect(find.text('BOUTIQUES\nDU MALI'), findsOneWidget);
    await tester.tap(banniere);
    await _avancer(tester);

    expect(find.text('PAGE BOUTIQUES'), findsOneWidget);
  });

  testWidgets('une seule ville : pas de pastilles qui ne trient rien', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      boutiques: [
        _boutique('a', 'Boutique A', 'Bamako'),
        _boutique('b', 'Boutique B', 'Bamako'),
      ],
    );

    expect(find.byType(ShopPill), findsNothing);
  });
}
