// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReviewImpl _$$ReviewImplFromJson(Map<String, dynamic> json) => _$ReviewImpl(
  id: json['id'] as String,
  orderId: json['order_id'] as String,
  supplierGroupId: json['supplier_group_id'] as String,
  clientId: json['client_id'] as String,
  supplierId: json['supplier_id'] as String,
  stars: (json['stars'] as num).toInt(),
  comment: json['comment'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
  supplierReply: json['supplier_reply'] as String?,
  supplierRepliedAt: json['supplier_replied_at'] == null
      ? null
      : DateTime.parse(json['supplier_replied_at'] as String),
);

Map<String, dynamic> _$$ReviewImplToJson(_$ReviewImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_id': instance.orderId,
      'supplier_group_id': instance.supplierGroupId,
      'client_id': instance.clientId,
      'supplier_id': instance.supplierId,
      'stars': instance.stars,
      'comment': instance.comment,
      'created_at': instance.createdAt.toIso8601String(),
      'supplier_reply': instance.supplierReply,
      'supplier_replied_at': instance.supplierRepliedAt?.toIso8601String(),
    };
