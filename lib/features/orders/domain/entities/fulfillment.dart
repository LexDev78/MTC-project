import 'package:freezed_annotation/freezed_annotation.dart';

part 'fulfillment.freezed.dart';
part 'fulfillment.g.dart';

/// Global, order-level choice for *where* the client receives the whole
/// order — distinct from the per-supplier [DeliveryMode] (features/orders/
/// domain/entities/order_status.dart), which decides *who* delivers each
/// supplier's items.
enum FulfillmentMethod {
  @JsonValue('pickup_point')
  pickupPoint,
  @JsonValue('home_delivery')
  homeDelivery;

  String get label => switch (this) {
    FulfillmentMethod.pickupPoint => 'Point de livraison',
    FulfillmentMethod.homeDelivery => 'Livraison à domicile',
  };
}

/// What the client's note to the supplier carries — replaces a plain
/// "courier comment" text field with either a written message or a voice
/// note, same local-file-only caveat as `ChatMessage`/`ProductComment`
/// attachments (features/chat, features/comments).
enum SupplierMessageType { none, text, voice }

/// A fixed MTC pickup location the client can choose instead of home
/// delivery — mocked (no real network of agencies yet), a handful of fixed
/// spots across the cities the app already knows about.
@freezed
class PickupPoint with _$PickupPoint {
  const factory PickupPoint({
    required String id,
    required String name,
    required String city,
    required String address,
    required double latitude,
    required double longitude,
  }) = _PickupPoint;

  factory PickupPoint.fromJson(Map<String, dynamic> json) =>
      _$PickupPointFromJson(json);
}
