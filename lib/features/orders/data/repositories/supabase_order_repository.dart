import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/error/exceptions.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/supabase_order_datasource.dart';

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository(this._datasource);

  final SupabaseOrderDatasource _datasource;

  @override
  Stream<List<Order>> watchOrdersForUser(String userId) {
    return _datasource
        .watchOrdersForUser(userId)
        .map((rows) => rows.map(Order.fromJson).toList());
  }

  @override
  Stream<Order> watchOrderById(String orderId) {
    return _datasource.watchOrderById(orderId).map(Order.fromJson);
  }

  @override
  Stream<List<Order>> watchOrdersForSupplier(String supplierId) {
    return _datasource
        .watchOrdersForSupplier(supplierId)
        .map((rows) => rows.map(Order.fromJson).toList());
  }

  @override
  Stream<List<Order>> watchAllOrders() {
    return _datasource.watchAllOrders().map((rows) => rows.map(Order.fromJson).toList());
  }

  @override
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
  }) async {
    // `clientId` is never sent to the RPC — it trusts `auth.uid()` alone
    // (see `place_order()`, `0003_orders_rpc.sql`), so a client can never
    // place an order as someone else.
    final groupsPayload = groups
        .map(
          (g) => {
            'supplier_id': g.supplierId,
            'supplier_name': g.supplierName,
            'delivery_mode': _deliveryModeToDb(g.deliveryMode),
            'delivery_fee_fcfa': g.deliveryMode == DeliveryMode.mtcDelivery
                ? g.mtcDeliveryFeeFcfa
                : 0,
            'items': g.items.map((i) => i.toJson()).toList(),
          },
        )
        .toList();

    final String orderId;
    try {
      orderId = await _datasource.placeOrder({
        'p_client_display_name_snapshot': clientDisplayNameSnapshot,
        'p_client_phone_snapshot': clientPhoneSnapshot,
        'p_groups': groupsPayload,
        'p_delivery_address_label': deliveryAddressLabel,
        'p_delivery_city': deliveryCity,
        'p_delivery_details': deliveryDetails,
        'p_delivery_latitude': deliveryLatitude,
        'p_delivery_longitude': deliveryLongitude,
        'p_fulfillment_method': _fulfillmentMethodToDb(fulfillmentMethod),
        'p_courier_phone': courierPhone,
        'p_alternate_phone': alternatePhone,
        // En UTC comme toutes les autres dates envoyées : stockée telle
        // quelle et relue en local, la journée choisie reste la même. Une
        // date locale sérialisée sans décalage serait relue comme de l'UTC,
        // et le créneau se déplacerait du fuseau de l'appareil.
        'p_delivery_date': deliveryDate?.toUtc().toIso8601String(),
        'p_delivery_time_slot_label': deliveryTimeSlotLabel,
        'p_is_priority': isPriority,
        'p_priority_fee_fcfa': priorityFeeFcfa,
        'p_supplier_message_type': supplierMessageType.name,
        'p_supplier_message_text': supplierMessageText,
        'p_supplier_message_voice_path': supplierMessageVoicePath,
        'p_supplier_message_voice_duration_seconds': supplierMessageVoiceDurationSeconds,
        'p_payment_method': _paymentMethodToDb(paymentMethod),
        'p_payment_status': _paymentStatusToDb(paymentStatus),
        'p_mobile_money_provider': mobileMoneyProvider == null
            ? null
            : _mobileMoneyProviderToDb(mobileMoneyProvider),
      });
    } on PostgrestException catch (e) {
      if (e.message.contains('Stock insuffisant')) {
        throw InsufficientStockException(e.message);
      }
      rethrow;
    }

    final row = await _datasource.fetchOrderById(orderId);
    return Order.fromJson(row);
  }

  @override
  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
    String? cancellationReason,
    CancelledBy? cancelledBy,
  }) async {
    try {
      await _datasource.updateGroupStatus(
        orderId: orderId,
        groupId: groupId,
        status: _orderStatusToDb(status),
        cancellationReason: cancellationReason,
        cancelledBy: cancelledBy?.name,
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('Transition invalide')) {
        throw ValidationException(e.message);
      }
      rethrow;
    }
  }

  @override
  Future<void> attachSupplierVoiceMessage({
    required String orderId,
    required String voicePath,
    required int durationSeconds,
  }) {
    return _datasource.setVoiceMessage(
      orderId: orderId,
      voicePath: voicePath,
      durationSeconds: durationSeconds,
    );
  }
}

String _orderStatusToDb(OrderStatus status) => switch (status) {
  OrderStatus.inTransit => 'in_transit',
  _ => status.name,
};

String _deliveryModeToDb(DeliveryMode mode) => switch (mode) {
  DeliveryMode.selfDelivery => 'self_delivery',
  DeliveryMode.mtcDelivery => 'mtc_delivery',
};

String _fulfillmentMethodToDb(FulfillmentMethod method) => switch (method) {
  FulfillmentMethod.pickupPoint => 'pickup_point',
  FulfillmentMethod.homeDelivery => 'home_delivery',
};

String _paymentMethodToDb(PaymentMethod method) => switch (method) {
  PaymentMethod.now => 'now',
  PaymentMethod.onDelivery => 'on_delivery',
};

String _paymentStatusToDb(PaymentStatus status) => switch (status) {
  PaymentStatus.paid => 'paid',
  PaymentStatus.pendingOnDelivery => 'pending_on_delivery',
};

String _mobileMoneyProviderToDb(MobileMoneyProvider provider) => switch (provider) {
  MobileMoneyProvider.orangeMoney => 'orange_money',
  MobileMoneyProvider.moovMoney => 'moov_money',
};
