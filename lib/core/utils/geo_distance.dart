import 'dart:math' as math;

/// Great-circle distance between two lat/lng points — plain doubles in,
/// plain double out, so callers don't need a mapping package dependency
/// (mirrors why `Address`/`PickupPoint` store raw doubles instead of a
/// `LatLng`, see features/profile/domain/entities/address.dart).
abstract final class GeoDistance {
  static const _earthRadiusKm = 6371.0;

  static double haversineKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);
}
