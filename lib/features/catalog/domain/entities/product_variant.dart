import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_variant.freezed.dart';
part 'product_variant.g.dart';

/// Which option a variant picked for one of its product's characteristics
/// — a variant has exactly one of these per characteristic it varies by.
/// Populated by `getById`'s nested select, aliased to `variant_options`
/// (`variants:product_variants(*, variant_options:product_variant_options(characteristic_id, option_id))`).
@freezed
class ProductVariantOptionRef with _$ProductVariantOptionRef {
  const factory ProductVariantOptionRef({
    required String characteristicId,
    required String optionId,
  }) = _ProductVariantOptionRef;

  factory ProductVariantOptionRef.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantOptionRefFromJson(json);
}

/// One purchasable combination of a product's characteristics (e.g.
/// "256Go / Noir") — its own price, stock, and photos, independent of the
/// parent product's (which become trigger-maintained aggregates once a
/// product has variants, see `0018_product_variants.sql`).
@freezed
class ProductVariant with _$ProductVariant {
  const factory ProductVariant({
    required String id,
    required String productId,
    required String name,
    required int priceFcfa,
    required int stockQuantity,
    @Default([]) List<String> imageUrls,

    /// Chemin d'objet Storage d'une courte vidéo de présentation (bucket
    /// `product-videos`, `0044_variant_video.sql`), jamais une URL résolue —
    /// même convention que [imageUrls]. `null` tant que le fournisseur n'en
    /// a pas ajouté, ce qui est le cas de l'immense majorité des variantes.
    String? videoPath,
    @Default(false) bool isDefault,
    @Default(0) int displayOrder,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'variant_options')
    @Default([])
    List<ProductVariantOptionRef> optionRefs,
  }) = _ProductVariant;

  factory ProductVariant.fromJson(Map<String, dynamic> json) =>
      _$ProductVariantFromJson(json);
}
