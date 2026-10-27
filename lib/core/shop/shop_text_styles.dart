import 'package:flutter/material.dart';

/// Les styles de texte qui n'ont pas de rôle dans le `TextTheme`.
abstract final class ShopTextStyles {
  /// La police des grands titres de bannière.
  ///
  /// Le kit les compose en Grandis Extended, une police commerciale dont la
  /// licence n'accompagne pas le kit (« All rights reserved »). Archivo,
  /// sous licence libre, en donne la même allure : une grotesque large, en
  /// graisse noire. La largeur passe par l'axe `wdth` de la police variable.
  static const String displayFamily = 'Archivo';

  /// Un titre de bannière, en capitales le plus souvent.
  ///
  /// Posé sur une photo voilée, donc blanc par défaut — le fond est sombre
  /// dans les deux thèmes.
  static TextStyle display({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w900,
    Color color = Colors.white,
    double? height = 1,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      color: color,
      height: height,
      // L'axe de graisse aussi, explicitement : sur une police variable,
      // `fontWeight` seul n'est pas appliqué partout.
      fontVariations: [
        const FontVariation('wdth', 125),
        FontVariation('wght', fontWeight.value.toDouble()),
      ],
    );
  }
}
