import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_component_themes.dart';
import 'app_text_theme.dart';

/// Material 3 theme built around an indigo/violet e-commerce palette.
///
/// Usage philosophy: violet is the seed/primary (main CTAs, active
/// navigation, links). Amber is reserved for the tertiary role — brand
/// accents such as "featured" badges — deliberately kept out of star ratings
/// (which stay amber too, but as an independent, universal idiom rather than
/// a brand-tinted one) so it doesn't get diluted into "just another accent".
/// Red is restricted to the semantic error role only (validation,
/// destructive actions), matching Material's own conventions.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandPrimary,
      tertiary: AppColors.brandAccent,
      error: AppColors.brandError,
      brightness: brightness,
    );

    final base = ThemeData(
      colorScheme: scheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: AppTextTheme.fontFamily,
      scaffoldBackgroundColor: scheme.surface,
    );

    return base.copyWith(
      textTheme: AppTextTheme.build(base.textTheme),
      filledButtonTheme: AppComponentThemes.filledButton(scheme),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(scheme),
      inputDecorationTheme: AppComponentThemes.inputDecoration(scheme),
      cardTheme: AppComponentThemes.card(scheme),
      navigationBarTheme: AppComponentThemes.navigationBar(scheme),
      chipTheme: AppComponentThemes.chip(scheme),
      appBarTheme: AppComponentThemes.appBar(scheme),
      visualDensity: VisualDensity.standard,
    );
  }
}
