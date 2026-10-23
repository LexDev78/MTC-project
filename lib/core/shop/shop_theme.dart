import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'shop_icons.dart';
import 'shop_tokens.dart';

/// Le thème du côté client, d'après `theme/` du kit FlutterShop.
///
/// Le kit gratuit ne livre que le clair (« le sombre est dans la version
/// complète ») ; ses jetons sombres, eux, y sont : toile `#16161E`, champs
/// `#1C1C25`, barre `#101015`. Le sombre ci-dessous en est construit, parce
/// qu'à MTC chaque écran se lit dans les deux modes.
///
/// Les tailles de texte suivent les maquettes du kit (titre de section 16,
/// titre d'écran 16, prix 16, texte secondaire 14 en noir 40), pas la
/// typographie Material par défaut.
abstract final class ShopTheme {
  static const String fontFamily = 'Plus Jakarta';

  /// Construits une fois : `ShopScope` les applique à chaque écran client.
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark ? ShopColors.black : Colors.white;
    final onBackground = isDark ? Colors.white : ShopColors.black;
    final secondaryText = isDark ? ShopColors.white60 : ShopColors.black40;
    final fill = isDark ? ShopColors.darkGrey : ShopColors.lightGrey;
    final border = isDark ? Colors.white10 : ShopColors.black10;
    final hint = isDark ? ShopColors.white40 : ShopColors.grey;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ShopColors.primary,
      onPrimary: Colors.white,
      primaryContainer: isDark
          ? ShopColors.primary.withValues(alpha: 0.16)
          : ShopColors.primarySwatch.shade50,
      onPrimaryContainer: isDark
          ? ShopColors.primarySwatch.shade200
          : ShopColors.primarySwatch.shade800,
      secondary: ShopColors.price,
      onSecondary: Colors.white,
      tertiary: ShopColors.warning,
      onTertiary: ShopColors.black,
      error: ShopColors.error,
      onError: Colors.white,
      errorContainer: ShopColors.error.withValues(alpha: isDark ? 0.2 : 0.1),
      onErrorContainer: isDark
          ? const Color(0xFFFF9C9C)
          : const Color(0xFFB3261E),
      surface: background,
      onSurface: onBackground,
      onSurfaceVariant: secondaryText,
      surfaceContainerLowest: background,
      surfaceContainerLow: fill,
      surfaceContainer: fill,
      surfaceContainerHigh: fill,
      surfaceContainerHighest: fill,
      outline: border,
      outlineVariant: border,
      shadow: Colors.black,
      inverseSurface: onBackground,
      onInverseSurface: background,
      inversePrimary: ShopColors.primarySwatch.shade200,
    );

    const roundedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
      borderSide: BorderSide(color: Colors.transparent),
    );

    final textTheme = TextTheme(
      headlineMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        color: onBackground,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: onBackground,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: onBackground,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: onBackground,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onBackground,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: onBackground),
      // Le kit met tout le texte courant en noir 40 : c'est ce qui donne
      // ses écrans aérés, où seuls titres et prix ressortent.
      bodyMedium: TextStyle(fontSize: 14, color: secondaryText, height: 1.4),
      bodySmall: TextStyle(fontSize: 12, color: secondaryText),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondaryText,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondaryText,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      colorScheme: scheme,
      primaryColor: ShopColors.primary,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: border,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onBackground, size: 24),
      // La flèche de retour du kit, fine, à la place de celle de Material.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (context) => const ShopIcon(ShopIcons.arrowLeft),
        closeButtonIconBuilder: (context) => const ShopIcon(ShopIcons.close),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onBackground),
        actionsIconTheme: IconThemeData(color: onBackground),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: onBackground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(ShopSizes.padding),
          backgroundColor: ShopColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ShopColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          minimumSize: const Size(double.infinity, 32),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.all(ShopSizes.padding),
          foregroundColor: onBackground,
          minimumSize: const Size(double.infinity, 32),
          side: BorderSide(width: 1.5, color: border),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ShopColors.primary,
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(ShopSizes.padding),
          backgroundColor: ShopColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 32),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint),
        contentPadding: const EdgeInsets.all(ShopSizes.padding),
        border: roundedBorder,
        enabledBorder: roundedBorder,
        disabledBorder: roundedBorder,
        focusedBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: ShopColors.primary),
        ),
        errorBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: ShopColors.error),
        ),
        focusedErrorBorder: roundedBorder.copyWith(
          borderSide: const BorderSide(color: ShopColors.error),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        checkColor: WidgetStateProperty.all(Colors.white),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShopColors.primary
              : Colors.transparent,
        ),
        side: BorderSide(color: border, width: 1.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius / 2)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShopColors.primary
              : border,
        ),
      ),
      // La réglette de prix : violette, sans ombre ni graduations — les
      // pas existent (`divisions`), les afficher en pointillés chargeait le
      // trait sans rien dire.
      sliderTheme: SliderThemeData(
        activeTrackColor: ShopColors.primary,
        inactiveTrackColor: onBackground.withValues(alpha: 0.1),
        thumbColor: ShopColors.primary,
        overlayColor: ShopColors.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        rangeThumbShape: const RoundRangeSliderThumbShape(
          enabledThumbRadius: 10,
          elevation: 0,
          pressedElevation: 0,
        ),
        rangeTickMarkShape: const RoundRangeSliderTickMarkShape(
          tickMarkRadius: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ShopColors.primary
              : (isDark ? ShopColors.white20 : ShopColors.black5),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: ShopColors.primary,
      ),
      cardTheme: CardThemeData(
        color: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(ShopSizes.radius),
          ),
          side: BorderSide(color: border),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onBackground,
        textColor: onBackground,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: onBackground,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: secondaryText,
        ),
        minLeadingWidth: 24,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ShopSizes.radius * 2),
          ),
        ),
        clipBehavior: Clip.hardEdge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ShopColors.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? Colors.white : ShopColors.black,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: isDark ? ShopColors.black : Colors.white,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? ShopColors.darkNavigationBar : Colors.white,
        selectedItemColor: ShopColors.primary,
        // Le kit n'écrit que le libellé de l'onglet actif : les autres sont
        // transparents, l'icône suffit.
        unselectedItemColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onBackground,
        unselectedLabelColor: secondaryText,
        indicatorColor: ShopColors.primary,
        dividerColor: border,
      ),
    );
  }
}
