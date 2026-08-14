library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Widget-level coverage of the "Commentaires produits" inbox reached from
/// the Produits tab — drives the real screens/router, the same way
/// `supplier_order_screen_test.dart`/`supplier_conversation_list_screen_test.dart`
/// do (see the layout-overflow bug that approach caught in Lot 5).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 opens the comment inbox from the Produits tab, sees the '
    'answered/pending seeded threads, and can reply from there',
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

      await tester.tap(find.byTooltip('Produits'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Commentaires produits'));
      await tester.pumpAndSettle();

      expect(find.text('Commentaires produits'), findsOneWidget);
      expect(find.text('Répondu'), findsOneWidget);
      expect(find.text('En attente'), findsOneWidget);
      expect(
        find.textContaining('Le tissu est-il aussi solide'),
        findsOneWidget,
      );

      await tester.tap(find.textContaining('Le tissu est-il aussi solide'));
      await tester.pumpAndSettle();

      // Opens the existing comments modal for that product.
      expect(find.text('Commentaires'), findsOneWidget);
      expect(find.text('Bogolan Bamako'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextField, 'Ajouter un commentaire...'),
        'Merci pour votre question, disponible sous 48h.',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // `findsWidgets` rather than `findsOneWidget`: `showModalBottomSheet`
      // leaves the inbox screen behind it onstage (see the Lot 5 note in
      // SUPPLIER_INTERFACE_PROGRESS.md), and it live-updates too — the new
      // top-level comment now also matches its own preview tile there.
      expect(
        find.text('Merci pour votre question, disponible sous 48h.'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
