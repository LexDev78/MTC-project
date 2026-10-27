import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/providers/screen_idle_provider.dart';

void main() {
  // `testWidgets` (not `test`) so the body runs inside Flutter test's fake
  // async zone — `tester.pump(duration)` fast-forwards the real `Timer`s
  // `ScreenIdleNotifier` creates, without an actual 10-second wait.
  testWidgets('flips to idle only after 10s with no activity', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(screenIdleProvider), isFalse);

    await tester.pump(const Duration(seconds: 9));
    expect(container.read(screenIdleProvider), isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(container.read(screenIdleProvider), isTrue);
  });

  testWidgets(
    'registering activity resets the clock, even after going idle once',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Providers are lazy — reading it once arms the timer at t=0.
      expect(container.read(screenIdleProvider), isFalse);

      await tester.pump(const Duration(seconds: 10));
      expect(container.read(screenIdleProvider), isTrue);

      container.read(screenIdleProvider.notifier).registerActivity();
      expect(container.read(screenIdleProvider), isFalse);

      await tester.pump(const Duration(seconds: 5));
      expect(container.read(screenIdleProvider), isFalse);

      await tester.pump(const Duration(seconds: 6));
      expect(container.read(screenIdleProvider), isTrue);
    },
  );
}
