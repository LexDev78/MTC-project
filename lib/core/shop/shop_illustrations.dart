import 'package:flutter/material.dart';

/// Les illustrations du kit FlutterShop, chacune en clair et en sombre.
///
/// Le kit dessine ses traits en noir sur fond transparent : posée telle
/// quelle sur la toile sombre, une illustration claire disparaît. D'où les
/// deux fichiers, choisis selon le thème — jamais l'un pour l'autre.
enum ShopIllustration {
  /// Un écran vide : panier, favoris, commandes, adresses.
  emptyState('empty_state'),

  /// Une recherche sans résultat, une liste de notifications vide.
  noResult('no_result'),

  /// Merci pour votre commande.
  orderSuccess('order_success'),

  /// Ajouté au panier.
  addedToCart('added_to_cart'),

  /// Paiement à la livraison.
  payOnDelivery('pay_on_delivery'),

  /// Activer les notifications.
  notifications('notifications'),

  /// Une action qui a échoué.
  failed('failed'),

  /// Pas de connexion internet.
  noInternet('no_internet'),

  /// Le serveur ne répond pas comme prévu.
  serverError('server_error'),

  /// Aide et assistance.
  help('help');

  const ShopIllustration(this._nom);

  final String _nom;

  String asset(Brightness brightness) =>
      'assets/shop/illustrations/${_nom}_${brightness == Brightness.dark ? 'dark' : 'light'}.png';
}

/// L'illustration à la taille demandée, dans la version du thème courant.
class ShopIllustrationImage extends StatelessWidget {
  const ShopIllustrationImage(this.illustration, {super.key, this.height});

  final ShopIllustration illustration;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final hauteur = height ?? MediaQuery.sizeOf(context).height * 0.3;
    return Image.asset(
      illustration.asset(Theme.of(context).brightness),
      height: hauteur,
      // Les fichiers font 500 à 750 px de côté : décodés à la taille
      // affichée, ils ne pèsent pas sur un téléphone d'entrée de gamme.
      cacheHeight: (hauteur * MediaQuery.devicePixelRatioOf(context)).round(),
      excludeFromSemantics: true,
    );
  }
}
