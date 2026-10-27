/// Design tokens for spacing and corner radii, used across the app so
/// screens share a consistent, "fluide" visual rhythm.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusPill = 999;

  /// Below this screen width, action bars swap text buttons for icon-only
  /// ones to avoid overflow (e.g. small phones like the iPhone SE).
  static const double compactScreenWidth = 380;
}
