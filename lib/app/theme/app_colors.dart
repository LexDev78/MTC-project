import 'package:flutter/material.dart';

/// Raw color constants for the MTC brand — an indigo/violet e-commerce
/// palette. Do not use these directly in widgets — prefer
/// [Theme.of(context).colorScheme] so light/dark mode and accessibility-safe
/// tones are respected.
abstract final class AppColors {
  static const Color brandPrimary = Color(0xFF5B4FE5);
  static const Color brandPrimaryDeep = Color(0xFF3F35B0);
  static const Color brandAccent = Color(0xFFFFB020);
  static const Color brandError = Color(0xFFE03131);

  static const Color neutralBackground = Color(0xFFF7F8FA);
  static const Color neutralBackgroundDark = Color(0xFF121218);

  /// Used behind the home hero banner and other "brand moment" surfaces.
  static const List<Color> heroGradient = [brandPrimaryDeep, brandPrimary];

  /// The moving-vehicle marker on the live tracking map needs to stand out
  /// against both the route line and the destination pin — kept as a
  /// distinct warm accent rather than tied to the brand color.
  static const Color mapVehicleAccent = Color(0xFFFF8A00);
}
