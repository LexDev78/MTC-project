library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../../test/support/supabase_test_harness.dart';

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

  await tester.tap(find.text('Se connecter')); // l'accueil
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur3 (unverified, no dossier yet) is forced straight into the '
    'KYC wizard instead of the dashboard',
    (tester) async {
      await _pumpApp(tester);
      await _login(tester, 'fournisseur3');

      expect(find.text('Vérification de votre compte'), findsOneWidget);
      // The individual ("fournisseur libre") form, not the company one.
      expect(find.text("Pièce d'identité"), findsOneWidget);
      expect(find.text('Tableau de bord'), findsNothing);
    },
  );

  testWidgets(
    'fournisseur4 (rejected) lands on the dashboard with the rejection '
    'reason and a way back into the wizard to correct it',
    (tester) async {
      await _pumpApp(tester);
      await _login(tester, 'fournisseur4');

      expect(find.text('Tableau de bord'), findsOneWidget);
      expect(find.text('Vérification refusée'), findsOneWidget);

      await tester.tap(find.text('Corriger mon dossier'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Vérification de votre compte'), findsOneWidget);
      expect(find.textContaining('RCCM'), findsWidgets);
    },
  );
}
