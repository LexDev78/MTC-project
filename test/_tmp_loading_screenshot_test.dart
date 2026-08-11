import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/app/app.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/screens/loading_screen.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MtcApp(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.text('Commencer'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('capture loading screen mid-animation', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'client1');
    await tester.enterText(fields.at(1), 'password123');
    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(LoadingScreen), findsOneWidget);
    await expectLater(
      find.byType(LoadingScreen),
      matchesGoldenFile('loading_mid_a.png'),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(LoadingScreen),
      matchesGoldenFile('loading_mid_b.png'),
    );

    await tester.pump(const Duration(milliseconds: 1100));
    await expectLater(
      find.byType(LoadingScreen),
      matchesGoldenFile('loading_exit.png'),
    );
  });
}
