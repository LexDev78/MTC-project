library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/shop/shop.dart';

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

  await tester.tap(find.text('Se connecter')); // l'accueil
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

  // L'accueil suit désormais `HomeScreen` du kit FlutterShop : offres et
  // catégories en tête, puis des sélections en carrousels de cartes du kit.
  // Les anciens onglets « Fournisseur principal » / « Fournisseurs tiers »,
  // le bandeau promo et la grille plate ont disparu avec lui.
  testWidgets('l\'accueil du kit : catégories, sélections, cartes produit', (
    tester,
  ) async {
    await _loginAsClient1(tester);

    expect(find.text('Catégories'), findsOneWidget);
    expect(find.text('Produits populaires'), findsOneWidget);
    expect(find.byType(ShopProductCard), findsWidgets);
  });

  // Ce qui comptait dans l'ancien cloisonnement par onglet — qu'une
  // sélection « fournisseurs tiers » ne mélange pas la vitrine MTC — est
  // vérifié sur la section qui le porte maintenant.
  testWidgets('« Fournisseurs tiers » ne liste que des boutiques tierces', (
    tester,
  ) async {
    await _loginAsClient1(tester);

    final section = find.widgetWithText(
      ProductCarouselSection,
      'Fournisseurs tiers',
    );
    await tester.scrollUntilVisible(
      section,
      300,
      // Le défilement vertical de la page, pas un carrousel horizontal.
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();

    final cartes = tester.widget<ProductCarouselSection>(section).products;
    expect(cartes, isNotEmpty);
    expect(
      cartes!.every((carte) => carte.brand != 'MTC Officiel'),
      isTrue,
      reason: 'la vitrine MTC (fournisseur principal) n\'est pas tierce',
    );
  });
}
