// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_variant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductVariantOptionRefImpl _$$ProductVariantOptionRefImplFromJson(
  Map<String, dynamic> json,
) => _$ProductVariantOptionRefImpl(
  characteristicId: json['characteristic_id'] as String,
  optionId: json['option_id'] as String,
);

Map<String, dynamic> _$$ProductVariantOptionRefImplToJson(
  _$ProductVariantOptionRefImpl instance,
) => <String, dynamic>{
  'characteristic_id': instance.characteristicId,
  'option_id': instance.optionId,
};

_$ProductVariantImpl _$$ProductVariantImplFromJson(Map<String, dynamic> json) =>
    _$ProductVariantImpl(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      name: json['name'] as String,
      priceFcfa: (json['price_fcfa'] as num).toInt(),
      stockQuantity: (json['stock_quantity'] as num).toInt(),
      imageUrls:
          (json['image_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      videoPath: json['video_path'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      optionRefs:
          (json['variant_options'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ProductVariantOptionRef.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ProductVariantImplToJson(
  _$ProductVariantImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_id': instance.productId,
  'name': instance.name,
  'price_fcfa': instance.priceFcfa,
  'stock_quantity': instance.stockQuantity,
  'image_urls': instance.imageUrls,
  'video_path': instance.videoPath,
  'is_default': instance.isDefault,
  'display_order': instance.displayOrder,
  'variant_options': instance.optionRefs,
};
