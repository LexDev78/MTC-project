import 'package:flutter/material.dart';

import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/delivery_tracking.dart';

/// L'arrivée estimée au-dessus de la carte, en carte du kit : l'icône de la
/// livraison, les minutes restantes, et la barre du trajet parcouru.
///
/// Le texte « Arrivée estimée : N min » tient en un seul `Text` : c'est la
/// seule valeur de l'écran qui bouge avec le livreur, et le parcours de
/// suivi la lit pour vérifier que la carte suit vraiment.
class EtaBanner extends StatelessWidget {
  const EtaBanner({super.key, required this.tracking});

  final DeliveryTracking tracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final livre = tracking.status == TrackingStatus.delivered;
    final teinte = livre ? ShopColors.success : ShopColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ShopSizes.screenMargin,
        ShopSizes.padding / 2,
        ShopSizes.screenMargin,
        ShopSizes.padding,
      ),
      child: Container(
        padding: const EdgeInsets.all(ShopSizes.padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ShopSizes.radius),
          border: Border.all(color: theme.dividerColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShopIcon(
                  livre ? ShopIcons.doublecheck : ShopIcons.delivery,
                  color: teinte,
                ),
                const SizedBox(width: ShopSizes.padding / 2),
                Expanded(
                  child: Text(
                    livre
                        ? 'Livré !'
                        : 'Arrivée estimée : ${tracking.etaMinutes} min',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ShopSizes.padding * 0.75),
            ClipRRect(
              borderRadius: BorderRadius.circular(ShopSizes.radius),
              child: LinearProgressIndicator(
                value: tracking.progressRatio,
                minHeight: 6,
                color: teinte,
                backgroundColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.08,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
