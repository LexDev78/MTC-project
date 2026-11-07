import 'package:flutter/material.dart';

import 'shop_theme.dart';

/// Applique le thème du kit FlutterShop au sous-arbre — le côté client.
///
/// Le reste de l'app (fournisseurs, livreurs, équipe MTC) garde le thème
/// MTC. Le mode clair ou sombre, lui, reste celui que l'utilisateur a
/// choisi : on le lit sur le thème englobant.
///
/// Les feuilles et boîtes de dialogue ouvertes depuis ce sous-arbre en
/// héritent aussi : `showModalBottomSheet` et `showDialog` capturent les
/// thèmes du contexte qui les ouvre.
class ShopScope extends StatelessWidget {
  const ShopScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sombre = Theme.of(context).brightness == Brightness.dark;
    return Theme(data: sombre ? ShopTheme.dark : ShopTheme.light, child: child);
  }
}
