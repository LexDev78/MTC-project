import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../domain/entities/delivery_tracking.dart';
import 'mock_route_generator.dart';

class InMemoryTrackingDatasource {
  final Map<String, List<LatLng>> _routeCache = {};

  /// Progress index shared across screens revisiting the same delivery, so
  /// navigating away and back resumes where it left off instead of
  /// restarting the simulated trip.
  final Map<String, int> _indexCache = {};

  Stream<DeliveryTracking> watch({
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  }) {
    final key = '$orderId:$groupId';
    final waypoints = _routeCache.putIfAbsent(
      key,
      () => MockRouteGenerator.generateWaypoints(
        origin: origin,
        destination: destination,
      ),
    );

    return Stream<DeliveryTracking>.multi((controller) {
      var index = _indexCache[key] ?? 0;

      DeliveryTracking snapshot() {
        final progress = waypoints.length <= 1
            ? 1.0
            : index / (waypoints.length - 1);
        final remainingSteps = waypoints.length - 1 - index;
        final status = index >= waypoints.length - 1
            ? TrackingStatus.delivered
            : TrackingStatus.inTransit;
        return DeliveryTracking(
          orderId: orderId,
          groupId: groupId,
          origin: origin,
          destination: destination,
          current: waypoints[index],
          route: waypoints,
          progressRatio: progress,
          etaMinutes: remainingSteps * 2,
          status: status,
        );
      }

      controller.add(snapshot());

      if (index >= waypoints.length - 1) return;

      final timer = Timer.periodic(const Duration(seconds: 2), (t) {
        if (index >= waypoints.length - 1) {
          t.cancel();
          return;
        }
        index++;
        _indexCache[key] = index;
        controller.add(snapshot());
        if (index >= waypoints.length - 1) t.cancel();
      });

      controller.onCancel = timer.cancel;
    }, isBroadcast: true);
  }
}
