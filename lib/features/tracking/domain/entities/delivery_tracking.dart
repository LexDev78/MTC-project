import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';

part 'delivery_tracking.freezed.dart';

enum TrackingStatus { preparing, inTransit, delivered }

@freezed
class DeliveryTracking with _$DeliveryTracking {
  const factory DeliveryTracking({
    required String orderId,
    required String groupId,
    required LatLng origin,
    required LatLng destination,
    required LatLng current,
    required List<LatLng> route,
    required double progressRatio,
    required int etaMinutes,
    required TrackingStatus status,
  }) = _DeliveryTracking;
}
