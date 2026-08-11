import 'package:freezed_annotation/freezed_annotation.dart';

import 'order_status.dart';

part 'order.freezed.dart';

@freezed
class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String productId,
    required String productNameSnapshot,
    required int unitPriceFcfaSnapshot,
    required int quantity,
  }) = _OrderItem;
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
  }) = _OrderSupplierGroup;
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String clientId,
    required List<OrderSupplierGroup> supplierGroups,
    required OrderStatus status,
    required DateTime placedAt,
    required int totalFcfa,
    required String deliveryAddressLabel,
    required String deliveryCity,
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,
  }) = _Order;
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
