import 'package:freezed_annotation/freezed_annotation.dart';

part 'promotion.freezed.dart';
part 'promotion.g.dart';

/// Comment la remise se calcule.
enum PromotionKind {
  @JsonValue('percentage')
  percentage,
  @JsonValue('fixed_amount')
  fixedAmount;

  String get label => switch (this) {
    PromotionKind.percentage => 'Pourcentage',
    PromotionKind.fixedAmount => 'Montant fixe',
  };
}

/// Une règle de remise posée par le fournisseur sur un de ses produits
/// (`product_promotions`, `0062`).
///
/// Une règle, pas un prix : ce qui est stocké est la condition (à partir de
/// quelle quantité, entre quelles dates) et la remise. Le prix s'en déduit
/// au moment où on en a besoin — sans quoi un prix figé survivrait à la
/// promotion qui l'a produit.
///
/// Plusieurs règles peuvent coexister sur un produit et **ne se cumulent
/// pas** : voir `promotion_pricing.dart`.
@freezed
class Promotion with _$Promotion {
  const factory Promotion({
    required String id,
    required String productId,
    required PromotionKind kind,

    /// Un pourcentage (1 à 90) ou un montant en FCFA, selon [kind].
    required int value,

    /// Remise sur quantité : s'applique à partir de ce nombre d'unités.
    @Default(1) int minQuantity,

    /// Fenêtre ouverte des deux côtés : `null` = déjà commencée / sans fin.
    DateTime? startsAt,
    DateTime? endsAt,
    @Default(true) bool isActive,

    /// Ce que le client lit sur la vignette (« Rentrée scolaire »).
    String? label,
  }) = _Promotion;

  factory Promotion.fromJson(Map<String, dynamic> json) =>
      _$PromotionFromJson(json);
}

extension PromotionX on Promotion {
  /// En cours à [now] (par défaut maintenant), indépendamment de la
  /// quantité.
  bool isRunningAt([DateTime? now]) {
    if (!isActive) return false;
    final moment = now ?? DateTime.now();
    final from = startsAt;
    final until = endsAt;
    if (from != null && moment.isBefore(from)) return false;
    if (until != null && !moment.isBefore(until)) return false;
    return true;
  }

  /// Applicable pour cette quantité, à cet instant.
  bool appliesTo(int quantity, [DateTime? now]) =>
      isRunningAt(now) && quantity >= minQuantity;

  /// Ce qu'il faut encore acheter pour y avoir droit — `0` si c'est déjà le
  /// cas. Sert à l'inciter (« encore 3 pour -20% »), pas à décider.
  int unitsMissingFor(int quantity) =>
      quantity >= minQuantity ? 0 : minQuantity - quantity;
}
