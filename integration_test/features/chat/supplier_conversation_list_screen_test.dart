library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Widget-level coverage of the supplier's Messages tab — drives the real
/// screens/router rather than just the repository, the same way
/// `supplier_order_screen_test.dart` does (see the layout-overflow bug that
/// approach caught in Lot 5). In particular this checks the tile/thread
/// title shows the *client's* name, not the supplier's own — a bug that a
/// pure repository test wouldn't catch since it only shows up in the
/// presentation-layer role branching.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'fournisseur1 sees Awa Traoré (not their own business name) on the '
    'Messages tab, can open the existing thread and reply to it',
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

      await tester.tap(find.byTooltip('Messages'));
      await tester.pumpAndSettle();

      expect(find.text('Awa Traoré'), findsOneWidget);
      expect(find.text('Bogolan Bamako'), findsNothing);

      await tester.tap(find.text('Awa Traoré'));
      await tester.pumpAndSettle();

      // AppBar title also resolves to the client's name, and the existing
      // message history is shown.
      expect(find.text('Awa Traoré'), findsOneWidget);
      expect(
        find.textContaining('disponible en plusieurs coloris'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byType(TextField),
        'Merci, je confirme la commande.',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      // Not a bare pumpAndSettle(): sending relies on a real Postgres
      // Realtime round-trip (write -> broadcast -> refetch), which isn't
      // driven by Flutter's frame scheduler, so pumpAndSettle() alone can
      // decide the tree is settled before the message arrives.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Merci, je confirme la commande.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
