library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/shop/shop.dart';

import '../../../test/support/supabase_test_harness.dart';

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
  // Settle splash timer + session restore, landing on the welcome screen.
  // Fixed durations rather than pumpAndSettle, like the rest of these
  // tests: loading skeletons elsewhere animate in a loop.
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

  testWidgets('mettre un article de côté le fait paraître dans Favoris', (
    tester,
  ) async {
    await _loginAsClient1(tester);

    // Awa (client1) a déjà un favori semé (le Tissu Bogolan traditionnel).
    // Les cartes du kit n'ont pas de cœur : on met de côté depuis la fiche,
    // avec le signet — sur un autre article, trouvé par la recherche.
    await tester.tap(find.byTooltip('Rechercher'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Panier tressé');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.tap(find.byType(ShopProductCard).first);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);

    // Retour à la coquille : la fiche, puis la recherche.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favoris'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Le favori semé et celui qu'on vient d'ajouter, en grille de cartes.
    expect(find.text('Aucun favori'), findsNothing);
    expect(find.text('2 articles'), findsOneWidget);
    expect(find.byType(ShopProductCard), findsNWidgets(2));
  });
}
