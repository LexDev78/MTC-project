import 'package:flutter_map/flutter_map.dart';

/// La source des tuiles, en un seul endroit.
///
/// Par défaut le serveur public d'OpenStreetMap : parfait pour développer,
/// mais sa politique d'usage **interdit** le trafic d'une application
/// installée — il est là pour la consultation occasionnelle et la mise au
/// point, pas pour servir une flotte de livreurs. Le passage à un
/// fournisseur sous contrat (MapTiler, Thunderforest, un cache maison) se
/// fait ici et nulle part ailleurs :
///
///   flutter build --dart-define=MAP_TILES_URL=https://tuiles.mtc.ml/{z}/{x}/{y}.png
///
/// Même principe que `OSRM_HOST` pour les itinéraires : deux réglages, deux
/// services, aucun code à toucher le jour de la bascule.
const mapTilesUrl = String.fromEnvironment(
  'MAP_TILES_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// Couche de tuiles commune à toutes les cartes de l'app.
TileLayer mtcTileLayer() => TileLayer(
  urlTemplate: mapTilesUrl,
  userAgentPackageName: 'com.mtc.mali_trade_connect',
);
