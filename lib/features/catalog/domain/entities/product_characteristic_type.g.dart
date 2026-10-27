// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_characteristic_type.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ProductCharacteristicTypeImpl _$$ProductCharacteristicTypeImplFromJson(
  Map<String, dynamic> json,
) => _$ProductCharacteristicTypeImpl(
  id: json['id'] as String,
  label: json['label'] as String,
  status: $enumDecode(_$CharacteristicTypeStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['created_at'] as String),
  proposedBySupplierId: json['proposed_by_supplier_id'] as String?,
  reviewedByStaffId: json['reviewed_by_staff_id'] as String?,
  reviewedAt: json['reviewed_at'] == null
      ? null
      : DateTime.parse(json['reviewed_at'] as String),
  rejectionReason: json['rejection_reason'] as String?,
);

Map<String, dynamic> _$$ProductCharacteristicTypeImplToJson(
  _$ProductCharacteristicTypeImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'status': _$CharacteristicTypeStatusEnumMap[instance.status]!,
  'created_at': instance.createdAt.toIso8601String(),
  'proposed_by_supplier_id': instance.proposedBySupplierId,
  'reviewed_by_staff_id': instance.reviewedByStaffId,
  'reviewed_at': instance.reviewedAt?.toIso8601String(),
  'rejection_reason': instance.rejectionReason,
};

const _$CharacteristicTypeStatusEnumMap = {
  CharacteristicTypeStatus.pending: 'pending',
  CharacteristicTypeStatus.approved: 'approved',
  CharacteristicTypeStatus.rejected: 'rejected',
};
