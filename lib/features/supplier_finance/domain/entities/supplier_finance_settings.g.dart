// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_finance_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SupplierFinanceSettingsImpl _$$SupplierFinanceSettingsImplFromJson(
  Map<String, dynamic> json,
) => _$SupplierFinanceSettingsImpl(
  supplierId: json['supplier_id'] as String,
  commissionRatePercent: (json['commission_rate_percent'] as num).toDouble(),
);

Map<String, dynamic> _$$SupplierFinanceSettingsImplToJson(
  _$SupplierFinanceSettingsImpl instance,
) => <String, dynamic>{
  'supplier_id': instance.supplierId,
  'commission_rate_percent': instance.commissionRatePercent,
};
