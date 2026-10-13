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

  /// Every order, unfiltered — admin only, cross-supplier (see
  /// `SupplierFinanceRepository.watchAllPayoutRequests` for the same
  /// admin-only shape). Never used to derive a single supplier's own view;
  /// that stays `watchOrdersForSupplier`.
  Stream<List<Order>> watchAllOrders();

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

    /// Code promo saisi par le client. Le serveur le revalide et le
    /// consomme lui-même : un code refusé fait échouer la commande plutôt
    /// que d'être ignoré, sinon on prélèverait plus que l'annoncé.
    String? promoCode,
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

  /// Records a supplier voice message's uploaded path on an already-placed
  /// order — a second step after `placeOrder`, since the voice note's
  /// Storage folder is keyed by the order's own id, which only exists once
  /// `placeOrder` has already returned it (see BACKEND_MIGRATION_PROGRESS.md,
  /// Lot 9).
  Future<void> attachSupplierVoiceMessage({
    required String orderId,
    required String voicePath,
    required int durationSeconds,
  });
}
