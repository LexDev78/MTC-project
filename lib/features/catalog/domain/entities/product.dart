import 'package:freezed_annotation/freezed_annotation.dart';

import 'product_category.dart';
import 'product_characteristic.dart';
import 'product_status.dart';
import 'product_variant.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String supplierId,
    required String supplierName,
    required SupplierType supplierType,
    required String name,
    required String description,
    required ProductCategory category,
    required int priceFcfa,
    required int stockQuantity,
    required List<String> imageUrls,
    required String city,
    required double ratingAverage,
    required int ratingCount,
    required bool allowsSelfDelivery,
    required bool allowsMtcDelivery,
    required DateTime createdAt,

    /// Shipping weight — feeds `computeHomeDeliveryFeeFcfa`
    /// (features/orders/domain/delivery_pricing.dart) alongside distance and
    /// category, so heavier items cost more to have MTC deliver. No longer
    /// a flat per-product fee: that's computed per order, per destination.
    required double weightKg,

    /// Denormalized from the supplier's verification status. Products from
    /// unverified/pending tiers suppliers are excluded from client-facing
    /// catalog queries — visibility on the platform is earned through
    /// verification + rating, per the product's trust model.
    @Default(true) bool isSupplierVerified,

    /// Selectable variants — empty when the product doesn't have that axis
    /// (e.g. a bag of cement has no size/color). Kept as plain label lists
    /// rather than a richer variant-pricing model since price doesn't
    /// change per variant in this catalog yet.
    @Default([]) List<String> sizes,
    @Default([]) List<String> colors,

    /// Where the product is manufactured/sourced from — defaults to Mali
    /// since most of the seeded catalog is local artisanal/agricultural
    /// goods; imported categories (electronics, some materials) override it.
    @Default(ProductRegion.mali) ProductRegion region,

    /// Lifecycle within the supplier's own catalog management — see
    /// `ProductStatus`'s doc comment. Defaults to `active` so every
    /// pre-existing seeded product (created before this field existed)
    /// stays visible without a data migration.
    @Default(ProductStatus.active) ProductStatus status,

    /// Below this stock level, the supplier's product list flags the item
    /// as low — `null` means no threshold is set (no warning is ever
    /// shown). A per-product setting rather than a platform-wide constant
    /// since restock lead time varies a lot by category (e.g. imported
    /// electronics vs. locally-milled rice).
    int? lowStockThreshold,

    /// The pre-discount price, shown struck through next to [priceFcfa]
    /// when set and higher than it — a plain "barré" price, not a
    /// scheduled/rule-based promotion engine.
    int? compareAtPriceFcfa,

    /// Bumped by [ProductRepository.incrementViewCount] once per client
    /// visit to the product's detail page — shown on the supplier
    /// dashboard, not client-facing anywhere.
    @Default(0) int viewCount,

    /// Trigger-maintained (`0018_product_variants.sql`) — the only
    /// reliable "does this product have variants" signal, true even from
    /// list queries (`watchProducts`/`watchMyProducts`) that don't embed
    /// [characteristics]/[variants] below. Never infer this from
    /// `characteristics.isEmpty`/`variants.isEmpty`: those are only
    /// populated by `getById`'s nested select.
    @Default(false) bool hasVariants,

    /// Trigger-maintained max variant price — `null` unless [hasVariants].
    /// Paired with [priceFcfa] (trigger-maintained min variant price once
    /// variants exist) to render "à partir de" range pricing without
    /// fetching [variants].
    int? maxPriceFcfa,

    /// Trigger-maintained count of this product's variants — `0` unless
    /// [hasVariants]. Lets list views show "N variantes" without embedding
    /// the full [variants] list.
    @Default(0) int variantCount,

    /// This product's characteristics (couleur/stockage/...), each with its
    /// own options — only populated via `getById`'s nested select (product
    /// detail, cart line, checkout, favorites resolve, chat attachment,
    /// stock-adjust sheet). Always empty from list queries.
    @Default([]) List<ProductCharacteristic> characteristics,

    /// This product's purchasable variants — same nested-select-only
    /// population as [characteristics].
    @Default([]) List<ProductVariant> variants,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);
}
