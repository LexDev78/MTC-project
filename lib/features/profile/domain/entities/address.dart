import 'package:freezed_annotation/freezed_annotation.dart';

part 'address.freezed.dart';
part 'address.g.dart';

/// Latitude/longitude kept as plain doubles (not `LatLng`) so the domain
/// layer has no dependency on the `latlong2` mapping package — the
/// tracking feature converts at its own presentation/data boundary.
@freezed
class Address with _$Address {
  const factory Address({
    required String id,
    required String userId,
    required String label,
    required String city,
    required String details,
    required double latitude,
    required double longitude,
  }) = _Address;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);
}
