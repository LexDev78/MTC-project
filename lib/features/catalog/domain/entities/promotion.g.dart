// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'promotion.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PromotionImpl _$$PromotionImplFromJson(Map<String, dynamic> json) =>
    _$PromotionImpl(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      kind: $enumDecode(_$PromotionKindEnumMap, json['kind']),
      value: (json['value'] as num).toInt(),
      minQuantity: (json['min_quantity'] as num?)?.toInt() ?? 1,
      startsAt: json['starts_at'] == null
          ? null
          : DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      label: json['label'] as String?,
    );

Map<String, dynamic> _$$PromotionImplToJson(_$PromotionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.productId,
      'kind': _$PromotionKindEnumMap[instance.kind]!,
      'value': instance.value,
      'min_quantity': instance.minQuantity,
      'starts_at': instance.startsAt?.toIso8601String(),
      'ends_at': instance.endsAt?.toIso8601String(),
      'is_active': instance.isActive,
      'label': instance.label,
    };

const _$PromotionKindEnumMap = {
  PromotionKind.percentage: 'percentage',
  PromotionKind.fixedAmount: 'fixed_amount',
};
