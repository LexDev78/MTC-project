// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SupplierProfileImpl _$$SupplierProfileImplFromJson(
  Map<String, dynamic> json,
) => _$SupplierProfileImpl(
  id: json['id'] as String,
  businessName: json['business_name'] as String,
  supplierType: $enumDecode(_$SupplierTypeEnumMap, json['supplier_type']),
  city: json['city'] as String,
  ratingAverage: (json['rating_average'] as num).toDouble(),
  ratingCount: (json['rating_count'] as num).toInt(),
  productCount: (json['product_count'] as num).toInt(),
  verificationStatus: $enumDecodeNullable(
    _$VerificationStatusEnumMap,
    json['verification_status'],
  ),
  legalType: $enumDecodeNullable(
    _$SupplierLegalTypeEnumMap,
    json['legal_type'],
  ),
  description: json['description'] as String?,
  bannerUrl: json['banner_url'] as String?,
  fullAddress: json['full_address'] as String?,
  addressLatitude: (json['address_latitude'] as num?)?.toDouble(),
  addressLongitude: (json['address_longitude'] as num?)?.toDouble(),
  publicPhoneNumbers:
      (json['public_phone_numbers'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  deliveryZones:
      (json['delivery_zones'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  openingHoursLabel: json['opening_hours_label'] as String?,
  isOpen: json['is_open'] as bool? ?? true,
);

Map<String, dynamic> _$$SupplierProfileImplToJson(
  _$SupplierProfileImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'business_name': instance.businessName,
  'supplier_type': _$SupplierTypeEnumMap[instance.supplierType]!,
  'city': instance.city,
  'rating_average': instance.ratingAverage,
  'rating_count': instance.ratingCount,
  'product_count': instance.productCount,
  'verification_status':
      _$VerificationStatusEnumMap[instance.verificationStatus],
  'legal_type': _$SupplierLegalTypeEnumMap[instance.legalType],
  'description': instance.description,
  'banner_url': instance.bannerUrl,
  'full_address': instance.fullAddress,
  'address_latitude': instance.addressLatitude,
  'address_longitude': instance.addressLongitude,
  'public_phone_numbers': instance.publicPhoneNumbers,
  'delivery_zones': instance.deliveryZones,
  'opening_hours_label': instance.openingHoursLabel,
  'is_open': instance.isOpen,
};

const _$SupplierTypeEnumMap = {
  SupplierType.tiers: 'tiers',
  SupplierType.principal: 'principal',
};

const _$VerificationStatusEnumMap = {
  VerificationStatus.unverified: 'unverified',
  VerificationStatus.pending: 'pending',
  VerificationStatus.verified: 'verified',
  VerificationStatus.rejected: 'rejected',
};

const _$SupplierLegalTypeEnumMap = {
  SupplierLegalType.company: 'company',
  SupplierLegalType.individual: 'individual',
};
