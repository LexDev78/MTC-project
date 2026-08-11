import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/features/tracking/data/datasources/in_memory_tracking_datasource.dart';
import 'package:mtc_app/features/tracking/data/datasources/mock_route_generator.dart';
import 'package:mtc_app/features/tracking/domain/entities/delivery_tracking.dart';

void main() {
  const bamako = LatLng(12.6392, -8.0029);
  const koutiala = LatLng(12.3912, -5.4642);

  group('MockRouteGenerator', () {
    test('anchors the route exactly on origin and destination', () {
      final waypoints = MockRouteGenerator.generateWaypoints(
        origin: bamako,
        destination: koutiala,
      );

      expect(waypoints.first, bamako);
      expect(waypoints.last, koutiala);
    });

    test('is deterministic for the same origin/destination pair', () {
      final a = MockRouteGenerator.generateWaypoints(
        origin: bamako,
        destination: koutiala,
      );
      final b = MockRouteGenerator.generateWaypoints(
        origin: bamako,
        destination: koutiala,
      );

      expect(a, b);
    });
  });

  group('InMemoryTrackingDatasource', () {
    test(
      'first snapshot starts in transit at the origin with full ETA',
      () async {
        final datasource = InMemoryTrackingDatasource();

        final first = await datasource
            .watch(
              orderId: 'order-1',
              groupId: 'group-1',
              origin: bamako,
              destination: koutiala,
            )
            .first;

        expect(first.status, TrackingStatus.inTransit);
        expect(first.current, bamako);
        expect(first.progressRatio, 0);
        expect(first.etaMinutes, greaterThan(0));
        expect(first.route.first, bamako);
        expect(first.route.last, koutiala);
      },
    );
  });
}
