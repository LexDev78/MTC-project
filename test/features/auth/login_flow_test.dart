import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MtcApp(),
    ),
  );
  // Settle splash timer + session restore, landing on the welcome screen.
  // Its ball animation runs on a ticker that never settles, so advance by
  // fixed durations here instead of pumpAndSettle.
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
  testWidgets('client1 logs in and lands on the two-tab client home', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _login(tester, 'client1');

    expect(find.text('Fournisseurs tiers'), findsOneWidget);
    expect(find.text('Fournisseur principal'), findsOneWidget);
    // Bottom nav present -> we're inside the client shell.
    expect(find.byTooltip('Profil'), findsOneWidget);
  });

  testWidgets(
    'fournisseur1 (verified) logs in and lands on the supplier dashboard',
    (tester) async {
      await _pumpApp(tester);
      await _login(tester, 'fournisseur1');

      expect(find.text('Espace fournisseur'), findsOneWidget);
      expect(find.text('Bienvenue, Bogolan Bamako'), findsOneWidget);
      expect(find.text('Identité vérifiée'), findsOneWidget);
    },
  );

  testWidgets('agent1 (MTC staff) logs in and lands on the MTC staff console', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _login(tester, 'agent1');

    expect(find.text('MTC — Espace staff'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
  });

  testWidgets('wrong password shows an error and stays on the login screen', (
    tester,
  ) async {
    await _pumpApp(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'client1');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Identifiants incorrects'), findsOneWidget);
  });
}
