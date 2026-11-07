// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movement.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StockMovementImpl _$$StockMovementImplFromJson(Map<String, dynamic> json) =>
    _$StockMovementImpl(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      quantityDelta: (json['quantity_delta'] as num).toInt(),
      reason: $enumDecode(_$StockMovementReasonEnumMap, json['reason']),
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      note: json['note'] as String?,
      variantId: json['variant_id'] as String?,
    );

Map<String, dynamic> _$$StockMovementImplToJson(_$StockMovementImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'product_id': instance.productId,
      'quantity_delta': instance.quantityDelta,
      'reason': _$StockMovementReasonEnumMap[instance.reason]!,
      'occurred_at': instance.occurredAt.toIso8601String(),
      'note': instance.note,
      'variant_id': instance.variantId,
    };

const _$StockMovementReasonEnumMap = {
  StockMovementReason.manualAdjustment: 'manual_adjustment',
  StockMovementReason.sale: 'sale',
  StockMovementReason.restock: 'restock',
  StockMovementReason.returned: 'returned',
  StockMovementReason.correction: 'correction',
};
