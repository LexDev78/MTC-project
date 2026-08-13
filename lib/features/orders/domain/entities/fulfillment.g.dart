// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fulfillment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PickupPointImpl _$$PickupPointImplFromJson(Map<String, dynamic> json) =>
    _$PickupPointImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );

Map<String, dynamic> _$$PickupPointImplToJson(_$PickupPointImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': instance.city,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
    };
