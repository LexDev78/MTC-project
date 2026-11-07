import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/promotion.dart';

/// La pastille de remise, sur une vignette ou une fiche.
///
/// Dit la remise, pas le prix : le prix remisé est affiché à côté par
/// `CurrencyText`, avec le prix barré. Répéter le montant ici obligerait à
/// le recalculer dans deux widgets.
///
/// La condition de quantité fait partie de la pastille (« dès 10 ») : une
/// remise annoncée sans sa condition est une promesse qu'on ne tient pas au
/// moment d'ajouter au panier.
class PromotionBadge extends StatelessWidget {
  const PromotionBadge({super.key, required this.promotion, this.compact = false});

  final Promotion promotion;

  /// Sur une vignette de catalogue, l'espace ne permet que l'essentiel.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = switch (promotion.kind) {
      PromotionKind.percentage => '-${promotion.value}%',
      PromotionKind.fixedAmount => '-${promotion.value} F',
    };
    final condition = promotion.minQuantity > 1
        ? ' dès ${promotion.minQuantity}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        compact ? '$text$condition' : '$text$condition${_suffix()}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onError,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _suffix() {
    final label = promotion.label;
    if (label == null || label.trim().isEmpty) return '';
    return ' · $label';
  }
}
