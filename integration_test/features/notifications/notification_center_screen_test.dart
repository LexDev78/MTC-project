library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Widget-level coverage of the notification bell on the "Tableau de bord"
/// tab — drives the real screens/router, the same way the Lot 8-12
/// supplier screens do.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 sees an unread badge on the bell, opens the notification '
    'center, and reading one clears it from the badge',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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

      // Une notification posée par le harnais plutôt que par un vrai
      // parcours (une commande, un message) : cet écran porte sur la cloche
      // et la pastille, pas sur ce qui les remplit.
      //
      // Passe par `service_role` depuis `0064` : une session, même
      // authentifiée, n'insère plus de notification — elles sont produites
      // par l'événement qui les justifie.
      await insertNotificationAsAdmin(
        userId: DemoIds.supplierBogolanBamako,
        type: 'new_order',
        title: 'Nouvelle commande',
        body: 'Awa Traoré — 1 article',
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget); // unread badge on the bell

      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Nouvelle commande'), findsOneWidget);
      expect(find.textContaining('Awa Traoré'), findsOneWidget);

      await tester.tap(find.text('Nouvelle commande'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      // The badge is gone now that the only notification is read.
      expect(find.text('1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
