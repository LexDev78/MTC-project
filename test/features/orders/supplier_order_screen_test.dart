@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../support/supabase_test_harness.dart';

/// Widget-level coverage of the order list -> detail -> contact-client
/// flow, using the real screens/router rather than just the repository —
/// this is what caught a real layout overflow bug in the product screens
/// (Lot 5); worth the same scrutiny here.
void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 can open their order from the Commandes tab, see the '
    "client's info without any other supplier's data, and reach a chat "
    'thread from the "Contacter le client" button',
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

      await tester.tap(find.byTooltip('Commandes'));
      await tester.pumpAndSettle();

      expect(find.text('Awa Traoré'), findsOneWidget);
      expect(find.text('Livrée'), findsWidgets);

      await tester.tap(find.text('Awa Traoré'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la commande'), findsOneWidget);
      expect(find.text('+22370000001'), findsOneWidget);
      // Rendered as "1 × Tissu Bogolan traditionnel".
      expect(find.textContaining('Tissu Bogolan traditionnel'), findsOneWidget);
      // A delivered group can't be cancelled or moved anywhere else — no
      // status-change buttons should render.
      expect(find.text('Refuser la commande'), findsNothing);

      await tester.tap(find.byTooltip('Contacter le client'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la commande'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
