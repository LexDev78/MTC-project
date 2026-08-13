@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../support/supabase_test_harness.dart';

/// Widget-level coverage of the storefront-profile form on the Profil tab
/// — drives the real screens/router, the same way the Lot 8/9/10 supplier
/// screens do (see the Lot 10 note in SUPPLIER_INTERFACE_PROGRESS.md about
/// a full-width-button theme crash that only showed up this way).
void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 edits the storefront form and toggles the shop closed '
    'from the Profil tab',
    (tester) async {
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

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();

      expect(find.text('Boutique ouverte'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description (optionnel)'),
        'Le meilleur bogolan de Bamako.',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adresse complète (optionnel)'),
        'Marché de Médine, Bamako',
      );

      await tester.scrollUntilVisible(
        find.text('Boutique ouverte'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Boutique ouverte'));
      await tester.pump();
      expect(
        find.text('Affichée comme "fermée" pour vos clients'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Enregistrer'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(find.text('Profil de la boutique mis à jour.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
