import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';

void main() {
  testWidgets('MtcApp boots to splash, then welcome, then login', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MtcApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MtcBrandMark), findsOneWidget);

    // Let the splash timer + auth session restore + route transition play
    // out. The welcome screen animates a continuously-running ticker, so it
    // can never satisfy pumpAndSettle — advance by fixed durations instead.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Trouver les articles du monde ici'), findsOneWidget);

    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Mali Trade Connect'), findsOneWidget);
  });
}
