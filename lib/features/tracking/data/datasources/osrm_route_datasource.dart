import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Un itinéraire routier : le tracé à suivre, et le temps qu'il demande.
typedef RoadRoute = ({List<LatLng> points, Duration duration, double distanceKm});

/// Calcul d'itinéraire par OSRM, le moteur de routage du projet
/// OpenStreetMap — même source de données que les tuiles de la carte.
///
/// **L'hôte par défaut est l'instance de démonstration publique**, sans clé
/// et pratique en développement, mais sa politique d'usage interdit le
/// trafic applicatif et elle n'offre aucune garantie de service : à
/// remplacer avant la mise en production par un OSRM auto-hébergé ou un
/// fournisseur sous contrat. Le remplacement se fait ici et nulle part
/// ailleurs :
///
///   flutter run --dart-define=OSRM_HOST=https://routage.mtc.ml
///
/// Toute panne de ce service rend `null` plutôt qu'une erreur : l'appelant
/// retombe alors sur la ligne droite. Une carte qui perd son tracé reste
/// utilisable ; une carte qui disparaît parce qu'un service tiers est
/// injoignable ne l'est pas.
class OsrmRouteDatasource {
  OsrmRouteDatasource({http.Client? client, String? host})
    : _client = client ?? http.Client(),
      _host =
          host ??
          const String.fromEnvironment(
            'OSRM_HOST',
            defaultValue: 'https://router.project-osrm.org',
          );

  final http.Client _client;
  final String _host;

  /// Au-delà, on considère le service injoignable et on rend la main. Six
  /// secondes : assez pour une requête lente, trop peu pour que le client
  /// regarde une carte figée en se demandant ce qui se passe.
  static const _timeout = Duration(seconds: 6);

  Future<RoadRoute?> road({required LatLng from, required LatLng to}) async {
    final uri = Uri.parse(
      '$_host/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return null;
      return parseOsrmResponse(response.body);
    } catch (_) {
      // Hors ligne, service saturé, réponse illisible : même conséquence,
      // l'appelant trace la ligne droite.
      return null;
    }
  }
}

/// Séparée de l'appel réseau pour être testable sans lui.
///
/// OSRM rend les coordonnées en GeoJSON, donc **longitude d'abord** — l'ordre
/// inverse de `LatLng`. Les intervertir donnerait un tracé qui part à l'autre
/// bout du monde sans qu'aucune erreur ne soit levée.
RoadRoute? parseOsrmResponse(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  if (json['code'] != 'Ok') return null;

  final routes = json['routes'] as List<dynamic>?;
  if (routes == null || routes.isEmpty) return null;

  final route = routes.first as Map<String, dynamic>;
  final coordinates =
      (route['geometry'] as Map<String, dynamic>)['coordinates'] as List<dynamic>;
  if (coordinates.isEmpty) return null;

  return (
    points: [
      for (final point in coordinates.cast<List<dynamic>>())
        LatLng((point[1] as num).toDouble(), (point[0] as num).toDouble()),
    ],
    duration: Duration(seconds: (route['duration'] as num).round()),
    distanceKm: (route['distance'] as num).toDouble() / 1000,
  );
}
