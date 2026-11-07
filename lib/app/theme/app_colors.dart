import 'package:flutter/material.dart';

/// Raw color constants for the MTC brand — an indigo/violet e-commerce
/// palette. Do not use these directly in widgets — prefer
/// [Theme.of(context).colorScheme] so light/dark mode and accessibility-safe
/// tones are respected.
///
/// Les quelques exceptions légitimes sont les « moments de marque » qui ne
/// correspondent à aucun rôle du `ColorScheme` (dégradé du héros, barre de
/// navigation peinte à la main) : chacune a sa variante claire *et* sombre
/// ci-dessous, à choisir sur la `brightness` du thème — jamais une couleur
/// claire codée en dur des deux côtés.
abstract final class AppColors {
  static const Color brandPrimary = Color(0xFF5B4FE5);
  static const Color brandPrimaryDeep = Color(0xFF3F35B0);
  static const Color brandAccent = Color(0xFFFFB020);
  static const Color brandError = Color(0xFFE03131);

  /// Violet de marque éclairci pour le sombre : `brandPrimary` sur un fond
  /// presque noir tombe à 2,6:1, illisible pour un prix ou un lien. Celui-ci
  /// tient 7,9:1 sur [neutralBackgroundDark] tout en restant la même teinte.
  static const Color brandPrimaryLight = Color(0xFFAC9FFF);

  static const Color neutralBackground = Color(0xFFF7F8FA);
  static const Color neutralBackgroundDark = Color(0xFF121218);

  /// Used behind the home hero banner and other "brand moment" surfaces.
  static const List<Color> heroGradient = [brandPrimaryDeep, brandPrimary];

  /// Fond de la barre de navigation incurvée, qui est peinte à la main
  /// (`CurvedIconNavBar`) et ne passe donc pas par le `ColorScheme`.
  ///
  /// En sombre, reprendre [brandPrimary] tel quel donnait la zone la plus
  /// lumineuse de tout l'écran, collée en bas, au-dessus d'un fond presque
  /// noir : la barre éblouissait et écrasait le contenu. Cette version
  /// profonde garde l'identité violette sans rayonner — c'est la bulle de
  /// l'onglet actif, elle restée en dégradé vif, qui porte l'accent.
  static const Color navBarLight = brandPrimary;
  static const Color navBarDark = Color(0xFF221C3E);

  /// The moving-vehicle marker on the live tracking map needs to stand out
  /// against both the route line and the destination pin — kept as a
  /// distinct warm accent rather than tied to the brand color.
  static const Color mapVehicleAccent = Color(0xFFFF8A00);
}
