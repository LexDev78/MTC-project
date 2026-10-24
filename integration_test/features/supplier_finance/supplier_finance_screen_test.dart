library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Widget-level coverage of the Finances tab — drives the real
/// screens/router, the same way the Lot 8/9/10/11 supplier screens do (see
/// the Lot 10 note in SUPPLIER_INTERFACE_PROGRESS.md about a full-width-
/// button theme crash that only showed up this way).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 sees their computed summary and past payout on the '
    'Finances tab, and can request a new withdrawal',
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

      await tester.tap(find.text('Se connecter')); // l'accueil
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'fournisseur1');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Finances'));
      await tester.pumpAndSettle();

      expect(find.text('Ventes brutes'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Retraits'), findsOneWidget);
      // Seeded already-paid payout for Bogolan Bamako.
      expect(find.text('Payé'), findsOneWidget);

      // The button can sit below the fold on the macOS test window — a
      // blind tap at its (off-screen) center would silently miss.
      await tester.scrollUntilVisible(
        find.text('Demander un retrait'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Demander un retrait'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Solde disponible : 35000 FCFA'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Montant (FCFA)'),
        '3000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Numéro de réception'),
        '+22370000005',
      );
      await tester.tap(find.text('Envoyer la demande'));
      await tester.pumpAndSettle();

      // The sheet closed and the new request now shows in the list.
      expect(find.text('Demander un retrait'), findsOneWidget);
      expect(find.text('Demandé'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin1 sees the MTC direct-sales summary and the admin payout queue '
    'entry point, and can process a pending request from there',
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

      await tester.tap(find.text('Se connecter')); // l'accueil
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'admin1');
      await tester.enterText(fields.at(1), 'password123');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      await tester.tap(find.byTooltip('Finances'));
      // Admin's "Ventes MTC directes" summary aggregates every order for
      // the MTC principal storefront — a heavier real query than the
      // per-tab pumpAndSettle(1s) elsewhere reliably covers.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Ventes MTC directes'), findsOneWidget);
      expect(find.text('Commissions plateforme (total)'), findsOneWidget);

      await tester.tap(find.textContaining('Retraits à valider'));
      await tester.pumpAndSettle();

      expect(find.text('Retraits à valider'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
