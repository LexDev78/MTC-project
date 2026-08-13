@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../support/supabase_test_harness.dart';

/// Widget-level coverage of the "Avis clients" management screen reached
/// from the Profil tab — drives the real screens/router, the same way the
/// Lot 8/9 supplier screens do (see the layout-overflow bug that approach
/// caught in Lot 5).
void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 opens the review inbox from the Profil tab and can '
    'reply to the seeded review',
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

      await tester.tap(find.byTooltip('Avis clients'));
      await tester.pumpAndSettle();

      expect(find.text('Avis clients'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(
        find.textContaining('Très beau tissu'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Écrire une réponse publique...'),
        'Merci pour votre confiance, à bientôt !',
      );
      await tester.tap(find.text('Envoyer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Merci pour votre confiance, à bientôt !'),
        findsOneWidget,
      );
      expect(find.text('Répondu'), findsOneWidget);
      expect(find.text('En attente'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
