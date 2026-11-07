library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/tracking/data/datasources/osrm_route_datasource.dart';

// Analyse de la réponse d'OSRM, sans réseau : c'est la partie qui peut se
// tromper en silence, puisqu'une erreur d'ordre de coordonnées produit un
// tracé parfaitement valide — simplement à l'autre bout du monde.
void main() {
  // Extrait réel : trois points entre deux rues de Bamako.
  const reponse = '''
  {
    "code": "Ok",
    "routes": [
      {
        "geometry": {
          "type": "LineString",
          "coordinates": [[-8.0029, 12.6392], [-7.9980, 12.6440], [-7.9929, 12.6492]]
        },
        "duration": 540.3,
        "distance": 2350.7
      }
    ]
  }
  ''';

  test('les coordonnées GeoJSON sont lues longitude d\'abord', () {
    final route = parseOsrmResponse(reponse);

    expect(route, isNotNull);
    expect(route!.points, hasLength(3));
    // Le piège : GeoJSON donne [lon, lat], `LatLng` attend (lat, lon).
    // Inversés, ces points tomberaient au large de la Somalie sans qu'aucune
    // erreur ne soit levée — la carte afficherait un tracé, juste absurde.
    expect(route.points.first.latitude, closeTo(12.6392, 0.0001));
    expect(route.points.first.longitude, closeTo(-8.0029, 0.0001));
    expect(route.points.last.latitude, closeTo(12.6492, 0.0001));
  });

  test('la durée et la distance sont converties', () {
    final route = parseOsrmResponse(reponse)!;
    expect(route.duration, const Duration(seconds: 540));
    expect(route.distanceKm, closeTo(2.3507, 0.0001));
  });

  test('une réponse en échec ne donne pas de tracé', () {
    // OSRM répond 200 avec un `code` d'erreur quand aucun itinéraire
    // n'existe : se fier au seul statut HTTP laisserait passer un `routes`
    // vide, et l'appel suivant planterait sur une liste sans premier élément.
    expect(parseOsrmResponse('{"code":"NoRoute","routes":[]}'), isNull);
    expect(parseOsrmResponse('{"code":"Ok","routes":[]}'), isNull);
  });
}
