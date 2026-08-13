@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../support/supabase_test_harness.dart';

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
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'creating a product through the real form shows it in the list as a '
    'draft, editing it to active updates the badge, and the stock sheet '
    'adjusts the quantity shown on the tile',
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
      await tester.enterText(formFields.at(4), '8'); // Stock
      await tester.enterText(formFields.at(6), '2.5'); // Poids
      await tester.enterText(formFields.at(7), 'Bamako'); // Ville

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
      expect(find.text('8 en stock'), findsOneWidget);

      // --- Edit: activate it ---
      await tester.tap(find.text('Tapis tressé test'));
      await tester.pumpAndSettle();
      expect(find.text('Modifier le produit'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Actif'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Actif'));
      await tester.scrollUntilVisible(
        find.text('Enregistrer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Actif'), findsWidgets);

      // --- Quick stock adjustment from the list tile ---
      // The list sorts newest-first, so the product just created above is
      // the first "Ajuster le stock" button among Bogolan Bamako's tiles.
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

      expect(find.text('13 en stock'), findsOneWidget);
    },
  );
}
