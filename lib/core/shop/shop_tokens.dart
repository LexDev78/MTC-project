import 'package:flutter/material.dart';

/// Les jetons du côté client, repris du kit FlutterShop
/// (`E-commerce-Complete-Flutter-UI/lib/constants.dart`).
///
/// Le client suit ce kit **à la lettre** : mêmes couleurs, mêmes marges,
/// mêmes rayons. Les écrans fournisseur et livreur gardent, eux, le thème
/// MTC (`AppColors`, `AppSpacing`). Rien ici ne doit donc servir hors de
/// `ShopScope`.
///
/// Les noms suivent le kit (« noir 80 » = noir à 80 % d'opacité, posé sur
/// blanc), pour qu'on retrouve d'un coup d'œil la valeur d'une maquette.
abstract final class ShopColors {
  /// La couleur d'accent du kit. Une seule par écran : l'action qui compte.
  static const primary = Color(0xFF7B61FF);

  static const primarySwatch = MaterialColor(0xFF9581FF, <int, Color>{
    50: Color(0xFFEFECFF),
    100: Color(0xFFD7D0FF),
    200: Color(0xFFBDB0FF),
    300: Color(0xFFA390FF),
    400: Color(0xFF8F79FF),
    500: Color(0xFF7B61FF),
    600: Color(0xFF7359FF),
    700: Color(0xFF684FFF),
    800: Color(0xFF5E45FF),
    900: Color(0xFF6C56DD),
  });

  static const black = Color(0xFF16161E);
  static const black80 = Color(0xFF45454B);
  static const black60 = Color(0xFF737378);
  static const black40 = Color(0xFFA2A2A5);
  static const black20 = Color(0xFFD0D0D2);
  static const black10 = Color(0xFFE8E8E9);
  static const black5 = Color(0xFFF3F3F4);

  static const white80 = Color(0xFFCCCCCC);
  static const white60 = Color(0xFF999999);
  static const white40 = Color(0xFF666666);
  static const white20 = Color(0xFF333333);
  static const white10 = Color(0xFF191919);

  static const grey = Color(0xFFB8B5C3);
  static const lightGrey = Color(0xFFF8F8F9);
  static const darkGrey = Color(0xFF1C1C25);

  static const success = Color(0xFF2ED573);
  static const warning = Color(0xFFFFBE21);
  static const error = Color(0xFFEA5B5B);

  /// Le bleu des prix sur les cartes du kit. Il n'a pas de rôle dans le
  /// `ColorScheme` : c'est une couleur de marque, lisible sur le blanc des
  /// cartes comme sur leur fond sombre (contraste ≥ 4,5:1 des deux côtés).
  static const price = Color(0xFF31B0D8);

  /// Le fond des barres de navigation du kit en sombre — un cran sous la
  /// toile, pour que la barre ne devienne pas la zone la plus claire.
  static const darkNavigationBar = Color(0xFF101015);
}

/// Marges, rayons et durées du kit.
///
/// Le kit compte en fractions de [padding] (½ = 8, ¼ = 4, 1,5 = 24) : les
/// constantes ci-dessous gardent ces valeurs exactes plutôt que d'arrondir
/// à l'échelle MTC, qui n'a pas de rayon 12.
abstract final class ShopSizes {
  static const double padding = 16;

  /// La marge latérale des écrans que le kit ne livre qu'en maquette
  /// (panier, paiement, recherche, commandes, notifications, adresses,
  /// avis, profil détaillé) : 64 px sur des captures à l'échelle 2.
  /// Les écrans dont le kit livre le code (accueil, fiche produit,
  /// découverte, favoris, profil) gardent [padding].
  static const double screenMargin = 32;

  static const double radius = 12;
  static const Duration duration = Duration(milliseconds: 300);

  /// Hauteur et largeur d'une carte produit verticale (`ProductCard` du
  /// kit), reprises telles quelles : les rangées horizontales en dépendent.
  static const double productCardWidth = 140;
  static const double productCardHeight = 220;

  /// Carte produit horizontale (« Les plus populaires »).
  static const double secondaryProductCardWidth = 256;
  static const double secondaryProductCardHeight = 114;
}
