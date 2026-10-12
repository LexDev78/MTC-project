library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

import '../../test/support/supabase_test_harness.dart';

Future<void> _loginAsClient1(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
      child: const MtcApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('Commencer'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'client1');
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets('"Fournisseur principal" is the first tab', (tester) async {
    await _loginAsClient1(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labels = tabBar.tabs
        .cast<Tab>()
        .map((tab) => tab.text)
        .toList();

    expect(labels, ['Fournisseur principal', 'Fournisseurs tiers']);
  });

  // Ce test affirmait auparavant que l'onglet principal montrait *aussi*
  // les produits tiers. La restructuration de l'accueil a tranché
  // l'inverse : chaque onglet est strictement cloisonné à son type de
  // fournisseur (voir le commentaire de `ClientHomeScreen`, et les deux
  // `CatalogTabScreen(supplierType: ...)` qu'il instancie). Ce qui compte
  // vraiment — que l'attribution du fournisseur reste visible sur la carte
  // produit — est donc vérifié là où ces produits s'affichent réellement :
  // l'onglet « Fournisseurs tiers ».
  testWidgets(
    'each tab is scoped to its own supplier type, and cards keep their '
    'supplier attribution',
    (tester) async {
      await _loginAsClient1(tester);

      // Les cartes rendues sont inspectées plutôt que cherchées par le nom
      // d'un fournisseur précis : la grille est paresseuse, donc chercher
      // « Bogolan Bamako » ne testerait en réalité que sa position dans le
      // défilement — un produit hors écran n'est pas construit du tout.
      final principalCards = tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .toList();
      expect(principalCards, isNotEmpty);
      expect(
        principalCards.every(
          (card) => card.product.supplierType == SupplierType.principal,
        ),
        isTrue,
        reason: "l'onglet principal ne doit lister que la vitrine MTC",
      );

      await tester.tap(find.text('Fournisseurs tiers'));
      await tester.pumpAndSettle();

      final tiersCards = tester
          .widgetList<ProductCard>(find.byType(ProductCard))
          .toList();
      expect(tiersCards, isNotEmpty);
      expect(
        tiersCards.every(
          (card) => card.product.supplierType == SupplierType.tiers,
        ),
        isTrue,
        reason: "l'onglet tiers ne doit lister que des fournisseurs tiers",
      );

      // L'attribution reste affichée sur la carte — vérifiée sur le
      // fournisseur réellement présent à l'écran, quel qu'il soit.
      expect(find.text(tiersCards.first.product.supplierName), findsWidgets);
    },
  );

  testWidgets('the promo banner scrolls away with the page', (tester) async {
    await _loginAsClient1(tester);

    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.text('Le meilleur du Mali,\nlivré chez vous'), findsOneWidget);

    // Drag the product list up to scroll the whole page.
    await tester.fling(
      find.byType(NestedScrollView),
      const Offset(0, -800),
      2000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Le meilleur du Mali,\nlivré chez vous'), findsNothing);
  });

  // Le test d'auto-défilement des rangées par catégorie après 10 s
  // d'inactivité a été retiré avec la fonctionnalité qu'il couvrait : les
  // onglets d'accueil rendent désormais une grille plate
  // (`CatalogTabScreen` → `ProductGrid`), plus de rangées groupées par
  // catégorie ni de `_AutoScrollingProductRow`. Le regroupement par
  // catégorie vit maintenant dans l'onglet « Catalogue »
  // (`CatalogueScreen`/`CategoryProductsScreen`), qui n'auto-défile pas.
  testWidgets('the home tabs render a flat product grid', (tester) async {
    await _loginAsClient1(tester);

    expect(find.byType(ProductCard), findsWidgets);
  });
}
