// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_characteristic.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductCharacteristicOptionImpl _$$ProductCharacteristicOptionImplFromJson(
  Map<String, dynamic> json,
) => _$ProductCharacteristicOptionImpl(
  id: json['id'] as String,
  characteristicId: json['characteristic_id'] as String,
  value: json['value'] as String,
  priceDeltaFcfa: (json['price_delta_fcfa'] as num?)?.toInt() ?? 0,
  displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$ProductCharacteristicOptionImplToJson(
  _$ProductCharacteristicOptionImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'characteristic_id': instance.characteristicId,
  'value': instance.value,
  'price_delta_fcfa': instance.priceDeltaFcfa,
  'display_order': instance.displayOrder,
};

_$ProductCharacteristicImpl _$$ProductCharacteristicImplFromJson(
  Map<String, dynamic> json,
) => _$ProductCharacteristicImpl(
  id: json['id'] as String,
  productId: json['product_id'] as String,
  type: ProductCharacteristicType.fromJson(
    json['type'] as Map<String, dynamic>,
  ),
  displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
  options:
      (json['options'] as List<dynamic>?)
          ?.map(
            (e) =>
                ProductCharacteristicOption.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$$ProductCharacteristicImplToJson(
  _$ProductCharacteristicImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'product_id': instance.productId,
  'type': instance.type,
  'display_order': instance.displayOrder,
  'options': instance.options,
};
