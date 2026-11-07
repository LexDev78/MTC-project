// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductImpl _$$ProductImplFromJson(Map<String, dynamic> json) =>
    _$ProductImpl(
      id: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: json['supplier_name'] as String,
      supplierType: $enumDecode(_$SupplierTypeEnumMap, json['supplier_type']),
      name: json['name'] as String,
      description: json['description'] as String,
      category: $enumDecode(_$ProductCategoryEnumMap, json['category']),
      priceFcfa: (json['price_fcfa'] as num).toInt(),
      stockQuantity: (json['stock_quantity'] as num).toInt(),
      imageUrls: (json['image_urls'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      city: json['city'] as String,
      ratingAverage: (json['rating_average'] as num).toDouble(),
      ratingCount: (json['rating_count'] as num).toInt(),
      allowsSelfDelivery: json['allows_self_delivery'] as bool,
      allowsMtcDelivery: json['allows_mtc_delivery'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
      isSupplierVerified: json['is_supplier_verified'] as bool? ?? true,
      sizes:
          (json['sizes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      colors:
          (json['colors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      region:
          $enumDecodeNullable(_$ProductRegionEnumMap, json['region']) ??
          ProductRegion.mali,
      status:
          $enumDecodeNullable(_$ProductStatusEnumMap, json['status']) ??
          ProductStatus.active,
      lowStockThreshold: (json['low_stock_threshold'] as num?)?.toInt(),
      compareAtPriceFcfa: (json['compare_at_price_fcfa'] as num?)?.toInt(),
      promotions:
          (json['promotions'] as List<dynamic>?)
              ?.map((e) => Promotion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      hasVariants: json['has_variants'] as bool? ?? false,
      maxPriceFcfa: (json['max_price_fcfa'] as num?)?.toInt(),
      variantCount: (json['variant_count'] as num?)?.toInt() ?? 0,
      characteristics:
          (json['characteristics'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ProductCharacteristic.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      variants:
          (json['variants'] as List<dynamic>?)
              ?.map((e) => ProductVariant.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ProductImplToJson(_$ProductImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'supplier_id': instance.supplierId,
      'supplier_name': instance.supplierName,
      'supplier_type': _$SupplierTypeEnumMap[instance.supplierType]!,
      'name': instance.name,
      'description': instance.description,
      'category': _$ProductCategoryEnumMap[instance.category]!,
      'price_fcfa': instance.priceFcfa,
      'stock_quantity': instance.stockQuantity,
      'image_urls': instance.imageUrls,
      'city': instance.city,
      'rating_average': instance.ratingAverage,
      'rating_count': instance.ratingCount,
      'allows_self_delivery': instance.allowsSelfDelivery,
      'allows_mtc_delivery': instance.allowsMtcDelivery,
      'created_at': instance.createdAt.toIso8601String(),
      'weight_kg': instance.weightKg,
      'is_supplier_verified': instance.isSupplierVerified,
      'sizes': instance.sizes,
      'colors': instance.colors,
      'region': _$ProductRegionEnumMap[instance.region]!,
      'status': _$ProductStatusEnumMap[instance.status]!,
      'low_stock_threshold': instance.lowStockThreshold,
      'compare_at_price_fcfa': instance.compareAtPriceFcfa,
      'promotions': instance.promotions,
      'view_count': instance.viewCount,
      'has_variants': instance.hasVariants,
      'max_price_fcfa': instance.maxPriceFcfa,
      'variant_count': instance.variantCount,
      'characteristics': instance.characteristics,
      'variants': instance.variants,
    };

const _$SupplierTypeEnumMap = {
  SupplierType.tiers: 'tiers',
  SupplierType.principal: 'principal',
};

const _$ProductCategoryEnumMap = {
  ProductCategory.textilesBogolan: 'textiles_bogolan',
  ProductCategory.artisanat: 'artisanat',
  ProductCategory.electronique: 'electronique',
  ProductCategory.alimentation: 'alimentation',
  ProductCategory.materiauxConstruction: 'materiaux_construction',
  ProductCategory.autre: 'autre',
};

const _$ProductRegionEnumMap = {
  ProductRegion.chine: 'chine',
  ProductRegion.europe: 'europe',
  ProductRegion.afriqueHorsMali: 'afrique_hors_mali',
  ProductRegion.mali: 'mali',
  ProductRegion.autre: 'autre',
};

const _$ProductStatusEnumMap = {
  ProductStatus.draft: 'draft',
  ProductStatus.active: 'active',
  ProductStatus.paused: 'paused',
  ProductStatus.archived: 'archived',
};
