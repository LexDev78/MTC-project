@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../support/supabase_test_harness.dart';

Future<void> _pumpApp(WidgetTester tester) async {
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
}

Future<void> _login(WidgetTester tester, String usernameOrPhone) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), usernameOrPhone);
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 can reach all 6 tabs, each showing its own screen',
    (tester) async {
      await _pumpApp(tester);
      await _login(tester, 'fournisseur1');

      expect(find.text('Tableau de bord'), findsOneWidget);

      await tester.tap(find.byTooltip('Produits'));
      await tester.pumpAndSettle();
      expect(find.text('Produits'), findsOneWidget);

      await tester.tap(find.byTooltip('Commandes'));
      await tester.pumpAndSettle();
      expect(find.text('Commandes'), findsOneWidget);

      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();
      expect(find.text('Messages'), findsOneWidget);

      await tester.tap(find.byTooltip('Finances'));
      await tester.pumpAndSettle();
      expect(find.text('Finances'), findsOneWidget);

      await tester.tap(find.byTooltip('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Déconnexion'), findsOneWidget);
    },
  );

  testWidgets(
    'agent1 (MTC staff) gets the same 6-tab shell shape, independently from '
    'the tiers shell',
    (tester) async {
      await _pumpApp(tester);
      await _login(tester, 'agent1');

      expect(find.text('Tableau de bord'), findsOneWidget);
      // The seeded Artisanat Sikasso dossier is `submitted`, so it shows up
      // as a count on the button rather than the bare label.
      expect(find.textContaining('Vérification des fournisseurs'), findsOneWidget);

      await tester.tap(find.byTooltip('Produits'));
      await tester.pumpAndSettle();
      expect(find.text('Produits'), findsOneWidget);
    },
  );

  testWidgets('logging out from the Profil tab returns to the login screen', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _login(tester, 'fournisseur1');

    await tester.tap(find.byTooltip('Profil'));
    await tester.pumpAndSettle();
    // The Lot 11 storefront form pushes the logout button below the fold —
    // scroll to it rather than tapping blind.
    await tester.scrollUntilVisible(
      find.text('Déconnexion'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Déconnexion'));
    // Not pumpAndSettle: like WelcomeScreen, LoginScreen carries a
    // continuously-ticking decorative animation (the watching cat) that
    // never reports itself settled — advance by fixed durations instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Se connecter'), findsOneWidget);
  });
}
