import '../entities/fulfillment.dart';
import '../entities/order.dart';
import '../entities/order_status.dart';
import '../entities/payment.dart';

abstract interface class OrderRepository {
  Stream<List<Order>> watchOrdersForUser(String userId);

  Stream<Order> watchOrderById(String orderId);

  /// Every order with at least one group belonging to [supplierId] — the
  /// order-level fields (delivery address, client snapshot, other
  /// suppliers' groups) come along with it, so the presentation layer must
  /// only ever read `supplierGroups.where((g) => g.supplierId == supplierId)`
  /// out of what this returns, never another supplier's own group (see
  /// `SupplierOrderView`).
  Stream<List<Order>> watchOrdersForSupplier(String supplierId);

  Future<Order> placeOrder({
    required String clientId,
    required String clientDisplayNameSnapshot,
    required String clientPhoneSnapshot,
    required List<CheckoutGroupInput> groups,
    required String deliveryAddressLabel,
    required String deliveryCity,
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,
    FulfillmentMethod fulfillmentMethod = FulfillmentMethod.homeDelivery,
    String? courierPhone,
    String? alternatePhone,
    DateTime? deliveryDate,
    String? deliveryTimeSlotLabel,
    bool isPriority = false,
    int priorityFeeFcfa = 0,
    SupplierMessageType supplierMessageType = SupplierMessageType.none,
    String? supplierMessageText,
    String? supplierMessageVoicePath,
    int? supplierMessageVoiceDurationSeconds,
    PaymentMethod paymentMethod = PaymentMethod.onDelivery,
    PaymentStatus paymentStatus = PaymentStatus.pendingOnDelivery,
    MobileMoneyProvider? mobileMoneyProvider,
  });

  /// Throws `ValidationException` if `status` isn't a valid move from the
  /// group's current status (see `order_status_transitions.isValidTransition`).
  /// [cancellationReason]/[cancelledBy] are only meaningful — and only
  /// stored — when [status] is `OrderStatus.cancelled`.
  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
    String? cancellationReason,
    CancelledBy? cancelledBy,
  });
}
