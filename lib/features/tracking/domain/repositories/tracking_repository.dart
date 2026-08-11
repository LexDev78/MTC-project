import 'package:latlong2/latlong.dart';

import '../entities/delivery_tracking.dart';

abstract interface class TrackingRepository {
  /// Emits a new snapshot every ~2s as the simulated delivery advances from
  /// [origin] to [destination]; completes once it reaches [TrackingStatus.delivered].
  Stream<DeliveryTracking> watchTrackingForOrder({
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
  });
}
