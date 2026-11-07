@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';

import 'support/supabase_test_harness.dart';

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  testWidgets('MtcApp boots to splash, then welcome, then login', (
    WidgetTester tester,
  ) async {
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
    await tester.pump();

    // Let the splash timer + auth session restore + route transition play
    // out, by fixed durations like the other boot tests.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bienvenue !'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bon retour !'), findsOneWidget);
  });
}
