library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/features/tracking/domain/route_follower.dart';

// La mesure qui décide de tout : « suis-je encore sur l'itinéraire ? »
void main() {
  // Un segment est-ouest d'environ 1,1 km, à Bamako.
  final trace = [
    const LatLng(12.6400, -8.0000),
    const LatLng(12.6400, -7.9900),
  ];

  test('un point posé sur le trace est à distance nulle', () {
    expect(
      distanceToRouteMeters(const LatLng(12.6400, -7.9950), trace),
      lessThan(1),
    );
  });

  test(
    'un point au milieu d\'un long segment est sur le trace, pas à '
    'des centaines de mètres de ses extrémités',
    () {
      // Le piège que ce calcul existe pour éviter : mesurer la distance aux
      // seuls sommets donnerait ici ~275 m, et déclencherait un recalcul
      // d'itinéraire à chaque position d'un livreur qui roule parfaitement
      // droit sur la route prévue.
      final auMilieu = const LatLng(12.6400, -7.9950);
      final auxSommets = [
        const Distance().as(LengthUnit.Meter, auMilieu, trace.first),
        const Distance().as(LengthUnit.Meter, auMilieu, trace.last),
      ].reduce((a, b) => a < b ? a : b);

      expect(auxSommets, greaterThan(200));
      expect(distanceToRouteMeters(auMilieu, trace), lessThan(1));
    },
  );

  test('un point sur une rue parallele est détecté comme hors trace', () {
    // ~110 m au nord du trace : au-delà du seuil de déviation.
    final parallele = const LatLng(12.6410, -7.9950);
    final ecart = distanceToRouteMeters(parallele, trace);

    expect(ecart, greaterThan(RouteFollower.deviationMeters));
    expect(ecart, closeTo(111, 10));
  });

  test(
    'un point légèrement à côté reste sur le trace — imprécision GPS et '
    'largeur de carrefour ne sont pas des déviations',
    () {
      // ~22 m au nord : un GPS urbain fait cette erreur sans que le livreur
      // ait quitté sa rue.
      final presque = const LatLng(12.6402, -7.9950);
      expect(
        distanceToRouteMeters(presque, trace),
        lessThan(RouteFollower.deviationMeters),
      );
    },
  );

  test('au-delà des extrémités, c\'est la distance au bout qui compte', () {
    // Un point à l'ouest du début du segment : le plus proche du trace est
    // son extrémité, pas la droite prolongée à l'infini.
    final avant = const LatLng(12.6400, -8.0100);
    expect(distanceToRouteMeters(avant, trace), closeTo(1085, 60));
  });
}
