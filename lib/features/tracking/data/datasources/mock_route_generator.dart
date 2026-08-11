import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Interpolates a "road-ish" path between two points — a straight
/// interpolation would look robotic on a map, so a small lateral jitter
/// (tapering to zero at both ends, so the route still starts/ends exactly
/// on the origin/destination) is layered on top. Deterministic per
/// origin/destination pair so the same delivery always draws the same path.
abstract final class MockRouteGenerator {
  static List<LatLng> generateWaypoints({
    required LatLng origin,
    required LatLng destination,
    int steps = 40,
  }) {
    final random = Random(origin.hashCode ^ destination.hashCode);

    final dx = destination.longitude - origin.longitude;
    final dy = destination.latitude - origin.latitude;
    final length = sqrt(dx * dx + dy * dy);
    final perpX = length == 0 ? 0.0 : -dy / length;
    final perpY = length == 0 ? 0.0 : dx / length;

    return List.generate(steps + 1, (i) {
      final t = i / steps;
      final baseLat = origin.latitude + dy * t;
      final baseLng = origin.longitude + dx * t;

      // Tapers to 0 at t=0 and t=1 via sin(t*pi), scaled by route length so
      // short in-city hops don't get a wildly oversized wiggle.
      final jitterMagnitude = sin(t * pi) * length * 0.15;
      final jitter = (random.nextDouble() - 0.5) * 2 * jitterMagnitude;

      return LatLng(baseLat + perpY * jitter, baseLng + perpX * jitter);
    });
  }
}
