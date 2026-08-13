// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payout_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PayoutRequestImpl _$$PayoutRequestImplFromJson(Map<String, dynamic> json) =>
    _$PayoutRequestImpl(
      id: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      amountFcfa: (json['amount_fcfa'] as num).toInt(),
      status: $enumDecode(_$PayoutStatusEnumMap, json['status']),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      method: $enumDecode(_$MobileMoneyProviderEnumMap, json['method']),
      payoutDestination: json['payout_destination'] as String,
      processedAt: json['processed_at'] == null
          ? null
          : DateTime.parse(json['processed_at'] as String),
      rejectionReason: json['rejection_reason'] as String?,
    );

Map<String, dynamic> _$$PayoutRequestImplToJson(_$PayoutRequestImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'supplier_id': instance.supplierId,
      'amount_fcfa': instance.amountFcfa,
      'status': _$PayoutStatusEnumMap[instance.status]!,
      'requested_at': instance.requestedAt.toIso8601String(),
      'method': _$MobileMoneyProviderEnumMap[instance.method]!,
      'payout_destination': instance.payoutDestination,
      'processed_at': instance.processedAt?.toIso8601String(),
      'rejection_reason': instance.rejectionReason,
    };

const _$PayoutStatusEnumMap = {
  PayoutStatus.requested: 'requested',
  PayoutStatus.processing: 'processing',
  PayoutStatus.paid: 'paid',
  PayoutStatus.rejected: 'rejected',
};

const _$MobileMoneyProviderEnumMap = {
  MobileMoneyProvider.orangeMoney: 'orange_money',
  MobileMoneyProvider.moovMoney: 'moov_money',
};
