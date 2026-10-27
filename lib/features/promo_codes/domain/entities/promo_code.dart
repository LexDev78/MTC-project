import 'package:freezed_annotation/freezed_annotation.dart';

part 'promo_code.freezed.dart';

/// Un code promo tel que son fournisseur le gère (`0071`).
///
/// Distinct d'une promotion (`Promotion`) : une promotion s'applique toute
/// seule à qui regarde la fiche, un code est **remis à quelqu'un** — un
/// client fidèle, un groupe WhatsApp, un flyer — et ne vaut que pour celui
/// qui le connaît. D'où des plafonds, une fenêtre, et une trace de qui s'en
/// est servi.
///
/// [productIds] vide signifie **tous les produits du fournisseur** : c'est
/// le cas le plus courant (« -10% sur ma boutique »), et l'écran le dit.
@freezed
class PromoCode with _$PromoCode {
  const factory PromoCode({
    required String id,
    required String code,
    required int percent,
    required bool isActive,
    required int usesCount,
    @Default(1) int maxUsesPerClient,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,

    /// `null` = sans plafond global.
    int? maxUses,
    int? minOrderFcfa,
    @Default([]) List<String> productIds,
    @Default([]) List<PromoCodeRedemption> redemptions,
  }) = _PromoCode;
}

/// Une utilisation du code : par qui, quand, pour combien, et sur quoi.
@freezed
class PromoCodeRedemption with _$PromoCodeRedemption {
  const factory PromoCodeRedemption({
    required String id,
    required DateTime createdAt,
    required int discountFcfa,
    required String clientName,
    @Default([]) List<PromoCodeRedemptionItem> items,
  }) = _PromoCodeRedemption;
}

/// Le nom du produit est **figé** à l'utilisation : un article renommé ou
/// retiré ne doit pas rendre l'historique illisible des mois après.
@freezed
class PromoCodeRedemptionItem with _$PromoCodeRedemptionItem {
  const factory PromoCodeRedemptionItem({
    required String productName,
    required int quantity,
    required int unitDiscountFcfa,
  }) = _PromoCodeRedemptionItem;
}

extension PromoCodeX on PromoCode {
  /// En vigueur maintenant : actif, dans sa fenêtre, et pas épuisé.
  bool get isUsable {
    if (!isActive) return false;
    final now = DateTime.now();
    final from = startsAt;
    final until = endsAt;
    if (from != null && now.isBefore(from)) return false;
    if (until != null && !now.isBefore(until)) return false;
    final cap = maxUses;
    if (cap != null && usesCount >= cap) return false;
    return true;
  }

  /// Ce qu'il reste à distribuer — `null` quand il n'y a pas de plafond.
  int? get remainingUses {
    final cap = maxUses;
    return cap == null ? null : (cap - usesCount).clamp(0, cap);
  }

  int get totalDiscountFcfa =>
      redemptions.fold(0, (sum, r) => sum + r.discountFcfa);
}

/// Ce qu'un code vaut sur le panier courant, tel que le serveur le calcule
/// (`preview_promo_code`, `0072`).
///
/// Un refus n'est pas une erreur : un code faux ou expiré est une réponse
/// normale de l'écran de paiement. [reason] porte de quoi l'expliquer.
@freezed
class PromoCodePreview with _$PromoCodePreview {
  const factory PromoCodePreview({
    required bool valid,
    String? reason,
    String? code,
    int? percent,
    String? supplierId,
    @Default(0) int discountFcfa,
  }) = _PromoCodePreview;
}
