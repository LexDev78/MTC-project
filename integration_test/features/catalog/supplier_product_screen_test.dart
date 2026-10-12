library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../../test/support/supabase_test_harness.dart';

/// End-to-end widget coverage of the product management screens — unlike
/// the repository/controller tests, this drives the actual `Form`s the way
/// a supplier would: filling `TextFormField`s and tapping real buttons,
/// through the real router/shell/providers wiring.
Future<void> _loginAsFournisseur1(WidgetTester tester) async {
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
  await tester.enterText(fields.at(0), 'fournisseur1');
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 1));

  await tester.tap(find.byTooltip('Produits'));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'creating a product through the real form shows it in the list as a '
    'draft, the stock sheet adjusts the quantity shown on its tile, and '
    'giving it a variant then switching it to active updates the badge',
    (tester) async {
      await _loginAsFournisseur1(tester);

      // --- Create ---
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau produit'), findsOneWidget);

      final formFields = find.byType(TextFormField);
      await tester.enterText(formFields.at(0), 'Tapis tressé test');
      await tester.enterText(
        formFields.at(1),
        'Tapis tressé à la main, article de test end-to-end.',
      );
      await tester.enterText(formFields.at(2), '17500'); // Prix
      // Stock is disabled at creation (starts at 0, set afterwards through
      // variants) — no longer a `TextFormField` here, so the indices below
      // shift down by one from what they'd be if it still were.
      await tester.enterText(formFields.at(5), '2.5'); // Poids
      await tester.enterText(formFields.at(6), 'Bamako'); // Ville

      await tester.scrollUntilVisible(
        find.text('Créer le produit'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Créer le produit'));
      await tester.pumpAndSettle();

      // Back on the list, the new product shows up as a draft.
      expect(find.text('Nouveau produit'), findsNothing); // form title gone
      expect(find.text('Tapis tressé test'), findsOneWidget);
      expect(find.text('Brouillon'), findsWidgets);
      expect(find.text('0 en stock'), findsOneWidget);

      // --- Quick stock adjustment from the list tile ---
      // Deliberately *before* adding a variant below: `adjust_stock`
      // (`0016_adjust_stock_rpc.sql`) refuses a product-level delta once
      // `has_variants` is set, since stock is scoped per variant from then
      // on. The list sorts newest-first, so the product just created above
      // is the first "Ajuster le stock" button among Bogolan Bamako's tiles.
      await tester.tap(find.byTooltip('Ajuster le stock').first);
      await tester.pumpAndSettle();
      expect(find.text('Tapis tressé test'), findsWidgets);

      // Not `find.byType(TextFormField).first` — the list screen's own
      // search field is still in the tree behind the modal sheet.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantité'),
        '5',
      );
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(find.text('5 en stock'), findsOneWidget);

      // --- Edit: give it a variant, then activate it ---
      // A product can't reach "Actif" variant-less —
      // `products_active_requires_variants`
      // (`0021_backfill_default_variants_and_require_variant.sql`), mirrored
      // client-side in `_submit`, blocks it with a SnackBar — so composing
      // one here is part of the activation path, not an extra step.
      await tester.tap(find.text('Tapis tressé test'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le produit'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Ajouter une variante'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ajouter une variante'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter un champ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Couleur').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('add-field-value-input')),
        'Naturel',
      );
      await tester.tap(find.text('Ajouter').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ajouter cette variante'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ajouter cette variante'));
      await tester.pumpAndSettle();
      expect(find.text('Variantes (1)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Actif'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Actif'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Enregistrer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Back on the list: the save went through (the form popped) and the
      // product now carries the "Actif" badge instead of "Brouillon".
      expect(find.text('Modifier le produit'), findsNothing);
      expect(find.text('Actif'), findsWidgets);
    },
  );
}
