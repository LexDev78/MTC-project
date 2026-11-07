import 'package:flutter/material.dart';

import 'package:mtc_app/core/utils/currency_formatter.dart';

import '../shop_tokens.dart';

/// Les tailles de prix du kit, de la carte de catalogue à la fiche.
enum ShopPriceSize {
  /// Carte produit : 12 et 10.
  card(12, 10),

  /// Ligne de panier ou de commande : 16 et 12.
  line(16, 12);

  const ShopPriceSize(this.current, this.previous);

  final double current;
  final double previous;
}

/// Le prix du kit : le montant à payer en bleu, l'ancien barré à côté.
///
/// L'ancien prix s'écrit sans unité : il se lit comme une comparaison, pas
/// comme un montant. Sur les cartes, le prix courant prend la forme courte
/// « 12 500 F » : « FCFA » et l'ancien prix ne tiennent pas ensemble dans
/// 140 points.
class ShopPrice extends StatelessWidget {
  const ShopPrice(
    this.priceFcfa, {
    super.key,
    this.compareAtFcfa,
    this.size = ShopPriceSize.card,
  });

  final int priceFcfa;

  /// Le prix avant remise, s'il est plus élevé.
  final int? compareAtFcfa;
  final ShopPriceSize size;

  @override
  Widget build(BuildContext context) {
    final avant = compareAtFcfa;
    final format = size == ShopPriceSize.card
        ? CurrencyFormatter.formatFcfaCompact
        : CurrencyFormatter.formatFcfa;
    final montant = Text(
      format(priceFcfa),
      maxLines: 1,
      style: TextStyle(
        color: ShopColors.price,
        fontWeight: FontWeight.w500,
        fontSize: size.current,
      ),
    );
    if (avant == null || avant <= priceFcfa) return montant;
    return Row(
      children: [
        montant,
        const SizedBox(width: ShopSizes.padding / 4),
        Flexible(
          child: Text(
            CurrencyFormatter.formatAmount(avant),
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: size.previous,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
      ],
    );
  }
}

/// La pastille rouge de remise, en haut à droite des photos produit.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge(this.percent, {super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: ShopSizes.padding / 2),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ShopColors.error,
        borderRadius: BorderRadius.all(Radius.circular(ShopSizes.radius)),
      ),
      child: Text(
        '-$percent %',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}
