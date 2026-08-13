@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

import '../support/supabase_test_harness.dart';

Future<void> _loginAsClient1(WidgetTester tester) async {
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
  await tester.enterText(fields.at(0), 'client1');
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets('"Fournisseur principal" is the first tab', (tester) async {
    await _loginAsClient1(tester);

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final labels = tabBar.tabs
        .cast<Tab>()
        .map((tab) => tab.text)
        .toList();

    expect(labels, ['Fournisseur principal', 'Fournisseurs tiers']);
  });

  testWidgets(
    'the principal tab shows third-party products too, without losing '
    'their own supplier attribution',
    (tester) async {
      await _loginAsClient1(tester);

      // Default landing tab is now "Fournisseur principal" (index 0).
      expect(find.text('Bogolan Bamako'), findsWidgets);
    },
  );

  testWidgets('the promo banner scrolls away with the page', (tester) async {
    await _loginAsClient1(tester);

    expect(find.byType(NestedScrollView), findsOneWidget);
    expect(find.text('Le meilleur du Mali,\nlivré chez vous'), findsOneWidget);

    // Drag the product list up to scroll the whole page.
    await tester.fling(
      find.byType(NestedScrollView),
      const Offset(0, -800),
      2000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Le meilleur du Mali,\nlivré chez vous'), findsNothing);
  });

  testWidgets(
    'the category product rows only auto-scroll after 10s of screen-wide '
    'inactivity, not on a fixed timer',
    (tester) async {
      await _loginAsClient1(tester);

      // A tiny net-zero drag registers as screen activity (resetting the
      // idle clock to a known zero point here) without actually moving
      // anything, regardless of how much simulated time the login flow's
      // pumpAndSettle already consumed.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 1));
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -1));
      await tester.pump();

      final cardFinder = find.byType(ProductCard).first;
      final positionBefore = tester.getTopLeft(cardFinder);

      // Well under the 10s idle threshold — nothing should have moved.
      await tester.pump(const Duration(seconds: 8));
      expect(tester.getTopLeft(cardFinder), positionBefore);

      // Past the threshold — auto-scroll starts, but its first tick is
      // still 4s away (it re-arms a fresh 4s periodic timer once idle).
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getTopLeft(cardFinder), positionBefore);

      // The first tick's `animateTo` needs incremental frames to actually
      // progress — a single huge `pump(duration)` jump doesn't drive its
      // ticker the way real frames would, so advance in small steps here.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(tester.getTopLeft(cardFinder), isNot(positionBefore));
    },
  );
}
