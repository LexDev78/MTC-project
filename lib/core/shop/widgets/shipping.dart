import 'package:flutter/material.dart';

import '../shop_icons.dart';
import '../shop_tokens.dart';

/// Le bleu pâle de la carte « Express » des maquettes.
const _bleuPale = Color(0xFFADDDEB);

/// L'accent d'une [ShippingMethodCard] : le violet de la marque, le bleu
/// pâle, ou un simple contour.
enum ShippingAccent {
  primary(ShopColors.primary, Colors.white),
  light(_bleuPale, ShopColors.black),
  none(null, null);

  const ShippingAccent(this.color, this.onColor);

  final Color? color;

  /// La couleur du bandeau du bas, posé sur [color].
  final Color? onColor;
}

/// Un mode de livraison (maquette « Shipping methods » du kit) : nom, délai
/// en gris, prix à droite ou lignes de tarif, et un bandeau de couleur sous
/// la carte quand elle est mise en avant.
class ShippingMethodCard extends StatelessWidget {
  const ShippingMethodCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.price,
    this.rates = const [],
    this.footer,
    this.accent = ShippingAccent.none,
  });

  final String title;
  final String subtitle;

  /// Une icône du kit devant le titre (`ShopIcons`).
  final String? icon;

  /// Le prix à droite du titre.
  final String? price;

  /// Des lignes « condition — montant » sous le délai.
  final List<(String, String)> rates;

  /// Le texte du bandeau ; sans accent, il n'est pas affiché.
  final String? footer;
  final ShippingAccent accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final encre = theme.colorScheme.onSurface;
    final interieur = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ShopSizes.padding * 1.25),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(ShopSizes.radius),
        border: accent == ShippingAccent.none
            ? Border.all(color: encre.withValues(alpha: 0.08), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                ShopIcon(icon!, color: encre),
                const SizedBox(width: ShopSizes.padding * 0.75),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (price != null) ...[
                const SizedBox(width: ShopSizes.padding / 2),
                Text(price!, style: theme.textTheme.titleSmall),
              ],
            ],
          ),
          const SizedBox(height: ShopSizes.padding / 2),
          Text(subtitle),
          if (rates.isNotEmpty) ...[
            const SizedBox(height: ShopSizes.padding),
            for (final (condition, montant) in rates)
              Padding(
                padding: const EdgeInsets.only(top: ShopSizes.padding / 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        condition,
                        style: TextStyle(color: encre, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: ShopSizes.padding / 2),
                    Text(montant, style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        ],
      ),
    );

    final couleur = accent.color;
    if (couleur == null) return interieur;
    return Container(
      decoration: BoxDecoration(
        color: couleur,
        borderRadius: BorderRadius.circular(ShopSizes.radius + 4),
      ),
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        children: [
          interieur,
          if (footer != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: ShopSizes.padding * 0.75,
                horizontal: ShopSizes.padding,
              ),
              child: Text(
                footer!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.onColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}
