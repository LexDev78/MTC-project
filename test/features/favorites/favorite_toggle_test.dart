import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/favorites/presentation/widgets/favorite_line_item.dart';

Future<void> _loginAsClient1(WidgetTester tester) async {
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

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'client1');
  await tester.enterText(fields.at(1), 'password123');
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

void main() {
  testWidgets('toggling a favorite from the catalog updates the Favoris tab', (
    tester,
  ) async {
    await _loginAsClient1(tester);

    // Awa (client1) already has one pre-seeded favorite; add a second one
    // by tapping the first visible favorite heart on the catalog grid.
    final hearts = find.byIcon(Icons.favorite_border_rounded);
    expect(hearts, findsWidgets);
    await tester.tap(hearts.first);
    await tester.pumpAndSettle();

    // Favoris is a direct bottom-nav tab now (icon-only bar, no labels).
    await tester.tap(find.byTooltip('Favoris'));
    await tester.pumpAndSettle();

    // The pre-seeded favorite plus the one just added — `FavoritesScreen`
    // renders them as a `ListView.separated` of `FavoriteLineItem`s, not a
    // grid.
    expect(find.text('Aucun favori pour le moment'), findsNothing);
    expect(find.byType(FavoriteLineItem), findsNWidgets(2));
  });
}
