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

/// Les numéros et l'adresse du client pour une commande, tels que le
/// serveur les laisse voir à celui qui demande (`client_contact`, `0120`).
///
/// Le client a tout. Ceux qui livrent ont le numéro ; la boutique a
/// l'adresse tant que sa part est en cours ; après la livraison, plus rien :
/// chaque champ absent l'est parce que l'appelant n'y a pas droit, pas parce
/// qu'il manque.
@freezed
class OrderContact with _$OrderContact {
  const OrderContact._();

  const factory OrderContact({
    /// Le numéro à appeler pour la livraison : celui donné au paiement,
    /// sinon celui du compte.
    String? phone,
    String? alternatePhone,

    /// Le nom de l'adresse (« Maison »), ou celui du point relais.
    String? addressLabel,
    String? addressDetails,
    double? latitude,
    double? longitude,
  }) = _OrderContact;

  factory OrderContact.fromJson(Map<String, dynamic> json) =>
      _$OrderContactFromJson(json);

  bool get hasAddress => addressLabel != null;
}

@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String clientId,

    /// Denormalized at `placeOrder` time from the client's account, the
    /// same way every other order/cart line snapshots the data it needs —
    /// so a supplier fulfilling the order can identify the client without a
    /// live join back to their (client-only-readable) profile.
    required String clientDisplayNameSnapshot,
    required List<OrderSupplierGroup> supplierGroups,
    required OrderStatus status,
    required DateTime placedAt,
    required int totalFcfa,

    /// La ville seule : elle ne désigne personne, et reste donc visible de
    /// tous ceux qui voient la commande.
    required String deliveryCity,

    /// Numéros et adresse — `null` quand l'appelant n'a plus droit à rien
    /// (une boutique dont la part est livrée, par exemple).
    OrderContact? clientContact,

    /// Where the client receives the order — home address or a pickup point
    /// (whose own name/address then fill [clientContact]). Defaulted so
    /// existing seed orders (all home addresses) don't need updating.
    @Default(FulfillmentMethod.homeDelivery) FulfillmentMethod fulfillmentMethod,
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
