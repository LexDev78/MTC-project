import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/features/tracking/data/datasources/osrm_route_datasource.dart';
import 'package:mtc_app/features/tracking/domain/route_follower.dart';
import 'package:mtc_app/features/tracking/presentation/providers/tracking_providers.dart';

import '../../domain/entities/courier_delivery.dart';
import 'courier_position_provider.dart';
import 'delivery_providers.dart';

/// Un suiveur d'itinéraire **par course**.
///
/// Son état — le tracé courant et le point d'où il part — n'a de sens que
/// pour une course donnée. Un suiveur partagé rendrait l'itinéraire de la
/// course précédente au premier appel de la suivante.
final _followerProvider = Provider.family<RouteFollower, String>((
  ref,
  deliveryId,
) {
  return RouteFollower(ref.watch(osrmRouteDatasourceProvider));
});

/// L'itinéraire du livreur vers son étape en cours, refait quand il quitte la
/// route.
///
/// Dépend de sa position : chaque nouvelle position relance le calcul, et
/// c'est [RouteFollower] qui décide s'il faut vraiment redemander un tracé au
/// service de routage ou rendre le précédent.
final navigationRouteProvider = FutureProvider.family<RoadRoute?, String>((
  ref,
  deliveryId,
) async {
  final deliveries = ref.watch(courierDeliveriesProvider).valueOrNull ?? const [];
  final delivery = deliveries.where((d) => d.id == deliveryId).firstOrNull;
  final leg = delivery?.currentLeg;
  if (leg == null) return null;

  final position = ref.watch(courierPositionProvider).valueOrNull;
  if (position == null) return null;

  return ref
      .watch(_followerProvider(deliveryId))
      .follow(
        from: LatLng(position.latitude, position.longitude),
        to: leg.target,
      );
});
