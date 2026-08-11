import 'package:freezed_annotation/freezed_annotation.dart';

import 'product_category.dart';

part 'product.freezed.dart';

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
    int? mtcDeliveryFeeFcfa,

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
  }) = _Product;
}
