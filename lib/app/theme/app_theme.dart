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

  /// Le clair reste généré depuis la graine : le mapping tonal de Material
  /// donne de bons tons clairs d'emblée.
  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.brandPrimary,
    tertiary: AppColors.brandAccent,
    error: AppColors.brandError,
    brightness: Brightness.light,
  );

  /// Le sombre, lui, est écrit à la main.
  ///
  /// `ColorScheme.fromSeed(brightness: dark)` dérive tout de la graine : les
  /// surfaces sortent teintées de violet (un gris lavande neutre nulle part),
  /// et le primaire devient un lilas pâle qui ne ressemble plus à la marque.
  /// Résultat à l'écran : des aplats ternes et des prix délavés.
  ///
  /// Ces valeurs-ci partent de l'inverse — des neutres franchement sombres,
  /// à peine réchauffés de violet, sur lesquels la couleur de marque est
  /// *posée* au lieu d'être diluée dedans :
  ///
  /// - l'échelle de surfaces part de [AppColors.neutralBackgroundDark]
  ///   (défini depuis le début mais que rien n'utilisait) et monte par
  ///   paliers lisibles, pour qu'une carte se détache de la page sans
  ///   élévation ni ombre ;
  /// - `primary` est le violet de marque éclairci ([AppColors
  ///   .brandPrimaryLight]) : 7,9:1 sur le fond, contre 2,6:1 pour le violet
  ///   d'origine — c'est lui qui porte les prix et les liens ;
  /// - l'ambre et le rouge sont remontés en clarté selon la même logique,
  ///   leurs versions nominales étant faites pour un fond blanc.
  ///
  /// Les paires on/container respectent toutes au moins 4,5:1 sur leur fond.
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,

    primary: AppColors.brandPrimaryLight,
    onPrimary: Color(0xFF1B1240),
    primaryContainer: Color(0xFF3A2F8F),
    onPrimaryContainer: Color(0xFFE4DEFF),

    secondary: Color(0xFFC7C2E8),
    onSecondary: Color(0xFF2A2546),
    secondaryContainer: Color(0xFF3B3663),
    onSecondaryContainer: Color(0xFFE3E0F7),

    tertiary: Color(0xFFFFC773),
    onTertiary: Color(0xFF3B2600),
    tertiaryContainer: Color(0xFF5A3B00),
    onTertiaryContainer: Color(0xFFFFE2B5),

    error: Color(0xFFFF8A8A),
    onError: Color(0xFF45090B),
    errorContainer: Color(0xFF7A1D1D),
    onErrorContainer: Color(0xFFFFDAD6),

    surface: AppColors.neutralBackgroundDark,
    onSurface: Color(0xFFECECF3),
    surfaceDim: Color(0xFF0C0C11),
    surfaceBright: Color(0xFF2E2E3A),
    surfaceContainerLowest: Color(0xFF0A0A0E),
    surfaceContainerLow: Color(0xFF1A1A22),
    surfaceContainer: Color(0xFF1F1F28),
    surfaceContainerHigh: Color(0xFF26262F),
    surfaceContainerHighest: Color(0xFF2E2E39),
    onSurfaceVariant: Color(0xFFADADBD),

    outline: Color(0xFF4A4A57),
    outlineVariant: Color(0xFF2F2F3A),

    inverseSurface: Color(0xFFE7E6EE),
    onInverseSurface: Color(0xFF1A1A22),
    inversePrimary: AppColors.brandPrimary,

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData _build(Brightness brightness) {
    final scheme = brightness == Brightness.dark ? _darkScheme : _lightScheme;

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
