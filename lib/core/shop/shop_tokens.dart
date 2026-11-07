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
///
/// Les valeurs de la charte MTC (« Logo, couleurs et police ») remplacent
/// celles du kit quand elle en donne une : le violet, le bleu du dégradé,
/// les vagues, les titres, les textes et les champs.
abstract final class ShopColors {
  /// Le violet de la charte, accent du côté client. Une seule action par
  /// écran le porte.
  static const primary = Color(0xFF7762F6);

  /// Le bleu où finit le dégradé de la charte.
  static const blue = Color(0xFF5A9EF9);

  /// Le bleu clair des vagues du logo.
  static const waves = Color(0xFF4FB4FA);

  /// Le dégradé de la charte, du violet au bleu : à 90° sur les boutons,
  /// à 135° sur le bandeau de l'accueil et de la connexion.
  static const gradient = [primary, blue];

  /// Le violet pour un texte ou un lien sur fond sombre : [primary] y tombe
  /// à 4,2:1, celui-ci tient 7,3:1 sur [black].
  static const primaryLight = Color(0xFFA799F9);

  static const primarySwatch = MaterialColor(0xFF9581FF, <int, Color>{
    50: Color(0xFFEFECFF),
    100: Color(0xFFD7D0FF),
    200: Color(0xFFBDB0FF),
    300: Color(0xFFA390FF),
    400: Color(0xFF8F79FF),
    500: Color(0xFF7762F6),
    600: Color(0xFF7359FF),
    700: Color(0xFF684FFF),
    800: Color(0xFF5E45FF),
    900: Color(0xFF6C56DD),
  });

  /// Les titres de la charte ; aussi la toile du mode sombre.
  static const black = Color(0xFF16161D);

  /// Les textes de la charte : sous-titres, texte courant, indications des
  /// champs. Plus foncé que le « noir 40 » du kit, qu'il remplace en clair :
  /// 5,1:1 sur blanc, contre 2,6:1.
  static const text = Color(0xFF6E6E76);

  /// Les icônes en tête des champs, sur [lightGrey].
  static const fieldIcon = Color(0xFF8E8C98);
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

  /// Le fond des champs de la charte.
  static const lightGrey = Color(0xFFF6F6F8);
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
