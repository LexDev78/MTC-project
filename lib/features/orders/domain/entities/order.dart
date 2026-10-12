import 'package:freezed_annotation/freezed_annotation.dart';

import 'fulfillment.dart';
import 'order_status.dart';
import 'payment.dart';

part 'order.freezed.dart';
part 'order.g.dart';

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    required String productNameSnapshot,
    required int unitPriceFcfaSnapshot,
    required int quantity,

    /// Which variant was ordered, if the product had variants at order
    /// time — `null` for a variant-less product.
    String? variantId,
    String? variantNameSnapshot,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);
}

/// One supplier's slice of an order — a single checkout can span multiple
/// suppliers, each with its own delivery choice and its own tracking leg.
@freezed
class OrderSupplierGroup with _$OrderSupplierGroup {
  const factory OrderSupplierGroup({
    required String id,
    required String supplierId,
    required String supplierName,
    required List<OrderItem> items,
    required DeliveryMode deliveryMode,
    required int deliveryFeeFcfa,
    required int subtotalFcfa,
    required OrderStatus status,

    /// Only set when [status] is `cancelled` — shown back to the client so
    /// a refusal isn't a silent dead end.
    String? cancellationReason,
    CancelledBy? cancelledBy,
  }) = _OrderSupplierGroup;

  factory OrderSupplierGroup.fromJson(Map<String, dynamic> json) =>
      _$OrderSupplierGroupFromJson(json);
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String clientId,

    /// Denormalized at `placeOrder` time from the client's account, the
    /// same way every other order/cart line snapshots the data it needs —
    /// so a supplier fulfilling the order can identify/reach the client
    /// without a live join back to their (client-only-readable) profile.
    required String clientDisplayNameSnapshot,
    required String clientPhoneSnapshot,
    required List<OrderSupplierGroup> supplierGroups,
    required OrderStatus status,
    required DateTime placedAt,
    required int totalFcfa,
    required String deliveryAddressLabel,
    required String deliveryCity,
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,

    /// Where the client receives the order — home address (the fields
    /// above are the client's saved address) or a pickup point (the fields
    /// above are that point's own name/city/address instead). Defaulted so
    /// existing seed orders (all home addresses) don't need updating.
    @Default(FulfillmentMethod.homeDelivery) FulfillmentMethod fulfillmentMethod,

    /// Only set for [FulfillmentMethod.homeDelivery].
    String? courierPhone,

    /// Optional second contact number, in case the courier can't reach the
    /// client on [courierPhone].
    String? alternatePhone,
    DateTime? deliveryDate,
    String? deliveryTimeSlotLabel,
    @Default(false) bool isPriority,
    @Default(0) int priorityFeeFcfa,

    /// The client's note to the supplier — text or voice, see
    /// [SupplierMessageType]. Only set for [FulfillmentMethod.homeDelivery].
    @Default(SupplierMessageType.none) SupplierMessageType supplierMessageType,
    String? supplierMessageText,
    String? supplierMessageVoicePath,
    int? supplierMessageVoiceDurationSeconds,

    @Default(PaymentMethod.onDelivery) PaymentMethod paymentMethod,
    @Default(PaymentStatus.pendingOnDelivery) PaymentStatus paymentStatus,
    MobileMoneyProvider? mobileMoneyProvider,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}

/// Input for [OrderRepository.placeOrder] — one supplier's checkout group,
/// built by the checkout controller from the current cart + chosen delivery
/// modes, before any order/group IDs exist.
@freezed
class CheckoutGroupInput with _$CheckoutGroupInput {
  const factory CheckoutGroupInput({
    required String supplierId,
    required String supplierName,
    required List<OrderItem> items,
    required DeliveryMode deliveryMode,
    required int mtcDeliveryFeeFcfa,
  }) = _CheckoutGroupInput;
}
