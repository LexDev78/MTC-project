// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CartItemImpl _$$CartItemImplFromJson(Map<String, dynamic> json) =>
    _$CartItemImpl(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      productId: json['product_id'] as String,
      supplierId: json['supplier_id'] as String,
      productNameSnapshot: json['product_name_snapshot'] as String,
      unitPriceFcfaSnapshot: (json['unit_price_fcfa_snapshot'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      addedAt: DateTime.parse(json['added_at'] as String),
      variantId: json['variant_id'] as String?,
      variantNameSnapshot: json['variant_name_snapshot'] as String?,
    );

Map<String, dynamic> _$$CartItemImplToJson(_$CartItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'product_id': instance.productId,
      'supplier_id': instance.supplierId,
      'product_name_snapshot': instance.productNameSnapshot,
      'unit_price_fcfa_snapshot': instance.unitPriceFcfaSnapshot,
      'quantity': instance.quantity,
      'added_at': instance.addedAt.toIso8601String(),
      'variant_id': instance.variantId,
      'variant_name_snapshot': instance.variantNameSnapshot,
    };
