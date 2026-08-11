import 'package:flutter/material.dart';

/// Soft "floating card" shadow used across product cards, hero banners and
/// bottom action bars so elevated surfaces read consistently even though
/// [CardThemeData.elevation] is kept at 0 (Material 3 tinting looks muddy
/// on the brand's saturated greens, so we draw shadows by hand instead).
abstract final class AppShadows {
  static List<BoxShadow> soft(Brightness brightness) {
    final opacity = brightness == Brightness.dark ? 0.28 : 0.08;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static List<BoxShadow> bar(Brightness brightness) {
    final opacity = brightness == Brightness.dark ? 0.35 : 0.06;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: opacity),
        blurRadius: 12,
        offset: const Offset(0, -2),
      ),
    ];
  }
}
