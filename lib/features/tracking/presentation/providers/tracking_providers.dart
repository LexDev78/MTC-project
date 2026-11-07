import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../data/datasources/in_memory_tracking_datasource.dart';
import '../../data/datasources/osrm_route_datasource.dart';
import '../../data/repositories/supabase_tracking_repository.dart';
import '../../domain/entities/delivery_tracking.dart';
import '../../domain/repositories/tracking_repository.dart';

final trackingDatasourceProvider = Provider<InMemoryTrackingDatasource>((ref) {
  return InMemoryTrackingDatasource();
});

/// Le suivi lit désormais la vraie position du livreur, poussée depuis son
/// app (`SupabaseTrackingRepository`). Le simulateur de trajet
/// (`InMemoryTrackingRepository`) reste dans le dépôt comme banc d'essai de
/// la carte, mais plus aucun écran ne l'utilise : montrer un livreur
/// imaginaire qui avance est pire que ne rien montrer, puisque le client
/// s'organise à partir de ce qu'il voit.
final osrmRouteDatasourceProvider = Provider<OsrmRouteDatasource>((ref) {
  return OsrmRouteDatasource();
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return SupabaseTrackingRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(osrmRouteDatasourceProvider),
  );
});

typedef TrackingParams = ({
  String groupId,
  LatLng origin,
  LatLng destination,
  bool isMtcDelivery,
});

/// Résout le point de départ (le fournisseur), l'arrivée (l'adresse de
/// livraison) et le fait que la course soit confiée à MTC — seule une
/// livraison MTC est suivie, puisqu'elle seule a un livreur qui transmet sa
/// position.
final trackingParamsProvider = FutureProvider.family<TrackingParams, String>((
  ref,
  orderId,
) async {
  final order = await ref.watch(orderDetailProvider(orderId).future);
  // Une commande chez deux boutiques peut avoir deux parts en route : celle
  // qu'un livreur MTC transporte est la seule qui se suive. La prendre
  // d'abord évite d'annoncer « Suivi indisponible » pour la part livrée par
  // la boutique quand l'autre, elle, est sur la carte.
  bool enRoute(OrderSupplierGroup g) => g.status == OrderStatus.inTransit;
  final group =
      order.supplierGroups.firstWhereOrNull(
        (g) => enRoute(g) && g.deliveryMode == DeliveryMode.mtcDelivery,
      ) ??
      order.supplierGroups.firstWhereOrNull(enRoute) ??
      order.supplierGroups.first;
  final supplier = await ref.watch(
    supplierDetailProvider(group.supplierId).future,
  );
  // L'adresse de retrait du fournisseur si elle existe (`0050` la rend
  // obligatoire pour une livraison MTC), sinon le centre de sa ville — le
  // départ reste affichable pour une commande ancienne, antérieure à cette
  // obligation.
  final origin = supplier.addressLatitude != null &&
          supplier.addressLongitude != null
      ? LatLng(supplier.addressLatitude!, supplier.addressLongitude!)
      : MalianCity.values
            .firstWhere(
              (c) => c.label == supplier.city,
              orElse: () => MalianCity.bamako,
            )
            .coordinates;

  return (
    groupId: group.id,
    origin: origin,
    // Le client voit toujours son adresse ; le centre de sa ville ne sert
    // que si le serveur n'a rien rendu.
    destination: switch (order.clientContact) {
      OrderContact(:final latitude?, :final longitude?) => LatLng(
        latitude,
        longitude,
      ),
      _ =>
        MalianCity.values
            .firstWhere(
              (c) => c.label == order.deliveryCity,
              orElse: () => MalianCity.bamako,
            )
            .coordinates,
    },
    isMtcDelivery: group.deliveryMode == DeliveryMode.mtcDelivery,
  );
});

final trackingStreamProvider = StreamProvider.family<DeliveryTracking, String>((
  ref,
  orderId,
) async* {
  final params = await ref.watch(trackingParamsProvider(orderId).future);
  yield* ref
      .watch(trackingRepositoryProvider)
      .watchTrackingForOrder(
        orderId: orderId,
        groupId: params.groupId,
        origin: params.origin,
        destination: params.destination,
      );
});
