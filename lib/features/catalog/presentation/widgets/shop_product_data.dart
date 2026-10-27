import 'package:mtc_app/core/shop/shop.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/promotion_pricing.dart';

/// Le prix d'une unité tel que le kit l'affiche : le montant à payer, et
/// l'ancien prix avec son pourcentage s'il y a vraiment une baisse.
typedef ShopUnitPricing = ({int priceFcfa, int? compareAtFcfa, int? percent});

/// Un produit du catalogue tel que les cartes et la fiche du kit
/// l'affichent.
///
/// Le prix est celui qui sera facturé : remise en cours comprise
/// (`bestPromotionFor`, la même règle que `place_order`), sans cumul.
/// L'ancien prix et le pourcentage n'apparaissent que s'il y a vraiment une
/// baisse — jamais de remise affichée qu'on ne paiera pas.
extension ProductShopData on Product {
  /// Le prix d'une unité de [basePriceFcfa] (une variante ; le produit par
  /// défaut) quand on en prend [quantity] : une remise « dès 10 » ne
  /// s'affiche pas à 1, sinon la fiche annoncerait un prix que le panier
  /// démentirait.
  ///
  /// L'ancien prix est le prix plein sous une remise, et sinon le prix
  /// barré décoratif saisi avant les promotions (`compareAtPriceFcfa`).
  ShopUnitPricing unitPricing({
    int? basePriceFcfa,
    int quantity = 1,
    DateTime? now,
  }) {
    final base = basePriceFcfa ?? priceFcfa;
    final remise = bestPromotionFor(
      promotions: promotions,
      basePriceFcfa: base,
      quantity: quantity,
      now: now,
    );
    final prix = remise == null
        ? base
        : priceUnderPromotion(basePriceFcfa: base, promotion: remise);
    final avant = remise != null ? base : compareAtPriceFcfa;
    final baisse = avant != null && avant > prix;
    return (
      priceFcfa: prix,
      compareAtFcfa: baisse ? avant : null,
      percent: baisse ? ((avant - prix) * 100 / avant).round() : null,
    );
  }

  ShopProductData shopData([DateTime? now]) {
    final prix = unitPricing(now: now);
    return ShopProductData(
      imagePath: imageUrls.isEmpty ? null : imageUrls.first,
      brand: supplierName,
      title: name,
      priceFcfa: prix.priceFcfa,
      compareAtFcfa: prix.compareAtFcfa,
      discountPercent: prix.percent,
    );
  }

  /// La remise en cours qui fait le prix d'une unité, s'il y en a une.
  Promotion? runningPromotion([DateTime? now]) => bestPromotionFor(
    promotions: promotions,
    basePriceFcfa: priceFcfa,
    quantity: 1,
    now: now,
  );
}

/// L'icône du kit la plus proche de chaque catégorie MTC — le jeu du kit
/// n'en a pas pour l'alimentation ou l'électronique, on prend la plus
/// parlante plutôt que de mêler des icônes d'un autre dessin.
extension ProductCategoryShopIcon on ProductCategory {
  String get shopIcon => switch (this) {
    ProductCategory.textilesBogolan => ShopIcons.manWoman,
    ProductCategory.artisanat => ShopIcons.gift,
    ProductCategory.electronique => ShopIcons.flashlight,
    ProductCategory.alimentation => ShopIcons.stores,
    ProductCategory.materiauxConstruction => ShopIcons.product,
    ProductCategory.autre => ShopIcons.category,
  };
}
