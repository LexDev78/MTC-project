import 'package:latlong2/latlong.dart';

/// Shared city -> coordinates table used by product/supplier seed data and
/// the tracking mock route generator, so seed data never disagrees about
/// where a city is.
enum MalianCity {
  bamako('Bamako', LatLng(12.6392, -8.0029)),
  sikasso('Sikasso', LatLng(11.3167, -5.6667)),
  segou('Ségou', LatLng(13.4317, -6.2157)),
  mopti('Mopti', LatLng(14.4843, -4.1824)),
  kayes('Kayes', LatLng(14.4469, -11.4443)),
  koutiala('Koutiala', LatLng(12.3912, -5.4642));

  const MalianCity(this.label, this.coordinates);

  final String label;
  final LatLng coordinates;
}
