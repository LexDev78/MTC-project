import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../data/datasources/in_memory_tracking_datasource.dart';
import '../../data/repositories/in_memory_tracking_repository.dart';
import '../../domain/entities/delivery_tracking.dart';
import '../../domain/repositories/tracking_repository.dart';

final trackingDatasourceProvider = Provider<InMemoryTrackingDatasource>((ref) {
  return InMemoryTrackingDatasource();
});

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  return InMemoryTrackingRepository(ref.watch(trackingDatasourceProvider));
});

typedef TrackingParams = ({String groupId, LatLng origin, LatLng destination});

/// Resolves an order's tracking origin (its in-transit supplier's city) and
/// destination (the delivery address) — the join `in_memory_tracking_*`
/// deliberately doesn't do itself, so it stays a pure route simulator.
final trackingParamsProvider = FutureProvider.family<TrackingParams, String>((
  ref,
  orderId,
) async {
  final order = await ref.watch(orderDetailProvider(orderId).future);
  final group = order.supplierGroups.firstWhere(
    (g) => g.status == OrderStatus.inTransit,
    orElse: () => order.supplierGroups.first,
  );
  final supplier = await ref.watch(
    supplierDetailProvider(group.supplierId).future,
  );
  final originCity = MalianCity.values.firstWhere(
    (c) => c.label == supplier.city,
    orElse: () => MalianCity.bamako,
  );

  return (
    groupId: group.id,
    origin: originCity.coordinates,
    destination: LatLng(order.deliveryLatitude, order.deliveryLongitude),
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
