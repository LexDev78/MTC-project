import '../domain/entities/fulfillment.dart';

/// Static — no repository/datasource ceremony, since (unlike products or
/// orders) this list never changes at runtime.
const List<PickupPoint> mockPickupPoints = [
  PickupPoint(
    id: 'pickup-bamako-hippodrome',
    name: 'Agence MTC — Hippodrome',
    city: 'Bamako',
    address: 'Avenue Cheick Zayed, Hippodrome',
    latitude: 12.6392,
    longitude: -8.0029,
  ),
  PickupPoint(
    id: 'pickup-bamako-badalabougou',
    name: 'Agence MTC — Badalabougou',
    city: 'Bamako',
    address: 'Rue 73, Badalabougou',
    latitude: 12.6229,
    longitude: -7.9887,
  ),
  PickupPoint(
    id: 'pickup-segou',
    name: 'Agence MTC — Ségou Centre',
    city: 'Ségou',
    address: 'Avenue de la République',
    latitude: 13.4317,
    longitude: -6.2157,
  ),
  PickupPoint(
    id: 'pickup-mopti',
    name: 'Agence MTC — Mopti',
    city: 'Mopti',
    address: 'Quartier Komoguel',
    latitude: 14.4843,
    longitude: -4.1824,
  ),
  PickupPoint(
    id: 'pickup-sikasso',
    name: 'Agence MTC — Sikasso',
    city: 'Sikasso',
    address: 'Route de Bamako',
    latitude: 11.3167,
    longitude: -5.6667,
  ),
];
