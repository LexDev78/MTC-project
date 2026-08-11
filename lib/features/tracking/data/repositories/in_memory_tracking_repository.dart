import 'package:latlong2/latlong.dart';

import '../../domain/entities/delivery_tracking.dart';
import '../../domain/repositories/tracking_repository.dart';
import '../datasources/in_memory_tracking_datasource.dart';

class InMemoryTrackingRepository implements TrackingRepository {
  InMemoryTrackingRepository(this._datasource);

  final InMemoryTrackingDatasource _datasource;

  @override
  Stream<DeliveryTracking> watchTrackingForOrder({
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  }) {
    return _datasource.watch(
      orderId: orderId,
      groupId: groupId,
      origin: origin,
      destination: destination,
    );
  }
}
