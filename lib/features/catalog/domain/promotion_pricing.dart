/// Le prix remisé, côté app.
///
/// **Ce calcul existe deux fois** : ici pour l'affichage, et dans
/// `effective_unit_price_fcfa` (`0062`) pour le montant réellement facturé.
/// Seule la version SQL fait foi — `place_order` ne lit aucun prix venu de
/// l'app. Cette version-ci sert à ne pas annoncer un prix différent de celui
/// qui sera prélevé.
///
/// Deux implémentations d'une même règle finissent par diverger, donc un
/// test les confronte sur une matrice de cas
/// (`test/features/catalog/promotion_pricing_test.dart`). Toute modification
/// ici doit l'être là aussi, et le test le dira.
///
/// La règle, en un mot : **jamais de cumul**. Parmi les remises applicables,
/// on retient celle qui donne le prix le plus bas. Empiler produirait des
/// prix que personne n'a voulus, et le résultat dépendrait de l'ordre
/// d'application — alors qu'aucun ordre n'est plus légitime qu'un autre.
library;

import 'entities/promotion.dart';

/// Le prix d'une unité sous une remise donnée, sans vérifier qu'elle
/// s'applique.
///
/// La division entière tronque, comme en SQL (`(base * value) / 100` sur des
/// entiers) : c'est ce qui garantit le même franc de part et d'autre.
int priceUnderPromotion({
  required int basePriceFcfa,
  required Promotion promotion,
}) {
  final discounted = switch (promotion.kind) {
    PromotionKind.percentage =>
      basePriceFcfa - (basePriceFcfa * promotion.value) ~/ 100,
    PromotionKind.fixedAmount => basePriceFcfa - promotion.value,
  };
  // Un prix nul traverserait les contrôles de stock et de paiement sans que
  // personne ne l'ait décidé. Même plancher qu'en base.
  return discounted < 1 ? 1 : discounted;
}

/// La remise retenue pour cette quantité, ou `null` s'il n'y en a aucune.
///
/// « Retenue » = celle qui donne le prix le plus bas. À prix égal, la
/// première rencontrée : l'affichage doit être stable d'un rendu à l'autre,
/// et les deux donnent le même montant de toute façon.
Promotion? bestPromotionFor({
  required List<Promotion> promotions,
  required int basePriceFcfa,
  required int quantity,
  DateTime? now,
}) {
  Promotion? best;
  int? bestPrice;
  for (final promotion in promotions) {
    if (!promotion.appliesTo(quantity, now)) continue;
    final price = priceUnderPromotion(
      basePriceFcfa: basePriceFcfa,
      promotion: promotion,
    );
    if (bestPrice == null || price < bestPrice) {
      best = promotion;
      bestPrice = price;
    }
  }
  // Une remise qui n'abaisse rien n'est pas une remise : une saisie à 0 F ou
  // un prix déjà au plancher ne doivent pas afficher de badge.
  if (bestPrice != null && bestPrice >= basePriceFcfa) return null;
  return best;
}

/// Le prix unitaire à afficher pour cette quantité.
int effectiveUnitPriceFcfa({
  required int basePriceFcfa,
  required List<Promotion> promotions,
  required int quantity,
  DateTime? now,
}) {
  final best = bestPromotionFor(
    promotions: promotions,
    basePriceFcfa: basePriceFcfa,
    quantity: quantity,
    now: now,
  );
  if (best == null) return basePriceFcfa;
  return priceUnderPromotion(basePriceFcfa: basePriceFcfa, promotion: best);
}

/// La prochaine remise que le client débloquerait en prenant davantage, et
/// ce qu'il lui manque pour y arriver.
///
/// Sert à l'annoncer (« encore 3 pour -20% ») : une remise sur quantité que
/// personne ne voit ne fait pas vendre une unité de plus.
({Promotion promotion, int unitsMissing})? nextQuantityStep({
  required List<Promotion> promotions,
  required int basePriceFcfa,
  required int quantity,
  DateTime? now,
}) {
  final current = effectiveUnitPriceFcfa(
    basePriceFcfa: basePriceFcfa,
    promotions: promotions,
    quantity: quantity,
    now: now,
  );

  ({Promotion promotion, int unitsMissing})? nearest;
  for (final promotion in promotions) {
    if (!promotion.isRunningAt(now)) continue;
    final missing = promotion.unitsMissingFor(quantity);
    if (missing == 0) continue;
    final price = priceUnderPromotion(
      basePriceFcfa: basePriceFcfa,
      promotion: promotion,
    );
    if (price >= current) continue;
    // Le palier le plus proche d'abord : c'est celui qu'on peut réellement
    // inciter à atteindre.
    if (nearest == null || missing < nearest.unitsMissing) {
      nearest = (promotion: promotion, unitsMissing: missing);
    }
  }
  return nearest;
}
