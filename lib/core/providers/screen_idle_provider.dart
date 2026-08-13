import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the client has gone [idleThreshold] without any real pointer
/// activity (tap, drag, scroll — anywhere on the screen, not just on one
/// widget). `ScreenIdleDetector` (core/widgets) feeds this by reporting
/// every pointer event it sees; `_AutoScrollingProductRow`
/// (features/catalog/presentation/screens/catalog_tab_screen.dart) only
/// auto-advances while this is `true`, so browsing never fights an
/// auto-scroll happening underneath it — the row only moves once the
/// client has genuinely stopped interacting with the page.
class ScreenIdleNotifier extends Notifier<bool> {
  static const idleThreshold = Duration(seconds: 10);

  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    _armTimer();
    return false;
  }

  /// Called on every real pointer event anywhere on the screen — resets the
  /// idle clock and immediately flips back to "active". Riverpod only
  /// notifies watchers when the value actually changes, so re-arming the
  /// timer while already active is cheap.
  void registerActivity() {
    state = false;
    _armTimer();
  }

  void _armTimer() {
    _timer?.cancel();
    _timer = Timer(idleThreshold, () => state = true);
  }
}

final screenIdleProvider = NotifierProvider<ScreenIdleNotifier, bool>(
  ScreenIdleNotifier.new,
);
