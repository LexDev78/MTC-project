import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/screen_idle_provider.dart';

/// Reports every real pointer interaction under [child] to
/// [screenIdleProvider] — translucent, so it only observes and never
/// intercepts or delays the gestures the wrapped content already handles.
class ScreenIdleDetector extends ConsumerWidget {
  const ScreenIdleDetector({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void registerActivity() =>
        ref.read(screenIdleProvider.notifier).registerActivity();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => registerActivity(),
      onPointerMove: (_) => registerActivity(),
      onPointerSignal: (_) => registerActivity(),
      child: child,
    );
  }
}
