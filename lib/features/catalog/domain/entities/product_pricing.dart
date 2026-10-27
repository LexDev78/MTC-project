import 'package:freezed_annotation/freezed_annotation.dart';

import 'product_category.dart';
import 'promotion.dart';

part 'product_pricing.freezed.dart';

/// Ce qu'il faut d'un produit pour calculer un prix et des frais de
/// livraison — rien de plus.
///
/// Existe pour une raison mesurable : le panier et l'écran de paiement
/// passaient par `getById`, dont la lecture imbriquée ramène les
/// caractéristiques, leurs options, les variantes et les options de chaque
/// variante. C'est ce qu'une fiche produit affiche ; pour un prix unitaire
/// c'est une requête lourde **par ligne de panier**, répétée à chaque
/// ouverture. `fetch_pricing_inputs` (`0068`) renvoie l'équivalent de cette
/// classe pour tous les produits du panier en un seul appel.
///
/// Assemblée à la main depuis le JSON : les variantes y sont une table
/// indexée par identifiant (c'est ainsi qu'on les consulte ici — « le prix
/// de la variante choisie »), pas une liste à parcourir.
@freezed
class ProductPricing with _$ProductPricing {
  const factory ProductPricing({
    required int priceFcfa,
    required int stockQuantity,
    required double weightKg,
    required ProductCategory category,
    required String city,
    required String supplierId,
    required String supplierName,
    required bool allowsSelfDelivery,
    required bool allowsMtcDelivery,
    @Default({}) Map<String, VariantPricing> variants,
    @Default([]) List<Promotion> promotions,
  }) = _ProductPricing;
}

@freezed
class VariantPricing with _$VariantPricing {
  const factory VariantPricing({
    required int priceFcfa,
    required int stockQuantity,
  }) = _VariantPricing;
}

extension ProductPricingX on ProductPricing {
  /// Le prix plein de la ligne : celui de la variante choisie, sinon celui
  /// du produit. Une variante retirée depuis la mise au panier retombe sur
  /// le prix du produit plutôt que de faire échouer l'affichage.
  int basePriceFor(String? variantId) =>
      variants[variantId]?.priceFcfa ?? priceFcfa;
}
