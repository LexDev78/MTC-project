import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../data/datasources/osrm_route_datasource.dart';

/// Garde l'itinéraire courant et décide **quand** le recalculer.
///
/// Deux raisons de recalculer, et une seule des deux est évidente :
///
///  * **Le livreur a quitté le tracé** — il a pris une autre rue, contourné un
///    blocage, s'est trompé. L'itinéraire affiché ne mène plus de là où il est
///    à là où il va : il faut le refaire tout de suite. C'est la distance au
///    **tracé** qui le dit, pas la distance au point de départ : quelqu'un qui
///    suit sagement la route s'en éloigne beaucoup sans jamais en sortir.
///  * **Il a avancé** le long du tracé. Rien n'est faux, mais la portion déjà
///    parcourue traîne derrière lui. On la rogne de temps en temps.
///
/// Sans la première, un livreur qui dévie garde un tracé absurde jusqu'à ce
/// qu'il ait parcouru la distance de rafraîchissement ; sans la seconde, on
/// redemanderait un itinéraire à chaque position reçue, soit tous les
/// cinquante mètres, pour redessiner presque le même trait.
class RouteFollower {
  RouteFollower(this._routes);

  final OsrmRouteDatasource _routes;

  RoadRoute? _route;
  LatLng? _routedFrom;
  LatLng? _routedTo;

  /// Au-delà, on considère que le livreur n'est plus sur l'itinéraire. 60 m
  /// laisse passer l'imprécision d'un GPS urbain et la largeur d'un carrefour,
  /// sans laisser passer une rue parallèle.
  static const deviationMeters = 60.0;

  /// Rafraîchissement de confort quand le livreur suit bien la route.
  static const progressMeters = 250.0;

  static const _distance = Distance();

  RoadRoute? get current => _route;

  /// L'itinéraire de [from] à [to], recalculé seulement si nécessaire.
  ///
  /// Rend `null` si le service de routage ne répond pas **et** qu'aucun tracé
  /// précédent n'est utilisable : l'appelant trace alors la ligne droite.
  Future<RoadRoute?> follow({required LatLng from, required LatLng to}) async {
    if (!_needsRecompute(from: from, to: to)) return _route;

    final route = await _routes.road(from: from, to: to);
    if (route == null) {
      // Service injoignable : on garde le tracé précédent s'il va au bon
      // endroit. Un itinéraire un peu vieux vaut mieux qu'une ligne droite,
      // et bien mieux qu'une carte qui clignote à chaque coupure réseau.
      return _routedTo == to ? _route : null;
    }
    _route = route;
    _routedFrom = from;
    _routedTo = to;
    return route;
  }

  bool _needsRecompute({required LatLng from, required LatLng to}) {
    final route = _route;
    if (route == null || _routedFrom == null || _routedTo != to) return true;
    if (distanceToRouteMeters(from, route.points) > deviationMeters) return true;
    return _distance.as(LengthUnit.Meter, _routedFrom!, from) > progressMeters;
  }
}

/// Distance d'un point au tracé, c'est-à-dire au plus proche de ses segments.
///
/// Mesurer la distance aux seuls **sommets** du tracé ne marcherait pas : sur
/// une longue ligne droite, OSRM ne rend que ses deux extrémités, et un point
/// au beau milieu s'en trouverait « à 400 m du tracé » alors qu'il est
/// exactement dessus.
double distanceToRouteMeters(LatLng point, List<LatLng> route) {
  if (route.isEmpty) return double.infinity;
  if (route.length == 1) {
    return const Distance().as(LengthUnit.Meter, point, route.first);
  }

  var best = double.infinity;
  for (var i = 0; i < route.length - 1; i++) {
    final d = _distanceToSegmentMeters(point, route[i], route[i + 1]);
    if (d < best) best = d;
  }
  return best;
}

/// Projection plane locale : à l'échelle d'une ville, un degré de latitude et
/// un degré de longitude (corrigé par le cosinus de la latitude) forment une
/// grille assez régulière pour projeter un point sur un segment. Faire ça sur
/// la sphère coûterait beaucoup de trigonométrie pour un écart de quelques
/// centimètres sur des segments de cette taille.
double _distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  const metersPerDegreeLat = 111320.0;
  final metersPerDegreeLon =
      metersPerDegreeLat * math.cos(p.latitude * math.pi / 180);

  double x(LatLng v) => v.longitude * metersPerDegreeLon;
  double y(LatLng v) => v.latitude * metersPerDegreeLat;

  final px = x(p), py = y(p);
  final ax = x(a), ay = y(a);
  final bx = x(b), by = y(b);

  final dx = bx - ax, dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));
  }

  // Position du projeté sur le segment, bornée à [0,1] : au-delà, le point le
  // plus proche est l'une des deux extrémités, pas la droite prolongée.
  final t = (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}
