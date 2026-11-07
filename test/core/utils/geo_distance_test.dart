import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/utils/geo_distance.dart';

void main() {
  test('distance from a point to itself is zero', () {
    final bamako = MalianCity.bamako.coordinates;
    final distance = GeoDistance.haversineKm(
      lat1: bamako.latitude,
      lon1: bamako.longitude,
      lat2: bamako.latitude,
      lon2: bamako.longitude,
    );

    expect(distance, 0);
  });

  test('Bamako-Ségou is roughly 200-260 km (real-world sanity check)', () {
    final bamako = MalianCity.bamako.coordinates;
    final segou = MalianCity.segou.coordinates;
    final distance = GeoDistance.haversineKm(
      lat1: bamako.latitude,
      lon1: bamako.longitude,
      lat2: segou.latitude,
      lon2: segou.longitude,
    );

    expect(distance, greaterThan(200));
    expect(distance, lessThan(260));
  });

  test('distance is symmetric', () {
    final bamako = MalianCity.bamako.coordinates;
    final mopti = MalianCity.mopti.coordinates;

    final aToB = GeoDistance.haversineKm(
      lat1: bamako.latitude,
      lon1: bamako.longitude,
      lat2: mopti.latitude,
      lon2: mopti.longitude,
    );
    final bToA = GeoDistance.haversineKm(
      lat1: mopti.latitude,
      lon1: mopti.longitude,
      lat2: bamako.latitude,
      lon2: bamako.longitude,
    );

    expect(aToB, closeTo(bToA, 0.0001));
  });
}
