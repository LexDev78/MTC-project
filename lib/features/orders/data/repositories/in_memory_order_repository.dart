import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/in_memory_order_datasource.dart';

class InMemoryOrderRepository implements OrderRepository {
  InMemoryOrderRepository(this._datasource);

  final InMemoryOrderDatasource _datasource;

  @override
  Stream<List<Order>> watchOrdersForUser(String userId) {
    return _datasource.watchAll().map(
      (orders) =>
          orders.where((o) => o.clientId == userId).toList()
            ..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
    );
  }

  @override
  Stream<Order> watchOrderById(String orderId) {
    return _datasource.watchAll().map(
      (orders) => orders.firstWhere((o) => o.id == orderId),
    );
  }

  @override
  Stream<List<Order>> watchOrdersForSupplier(String supplierId) {
    return _datasource.watchAll().map(
      (orders) =>
          orders
              .where(
                (o) => o.supplierGroups.any((g) => g.supplierId == supplierId),
              )
              .toList()
            ..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
    );
  }

  @override
  Stream<List<Order>> watchAllOrders() {
    return _datasource.watchAll().map(
      (orders) => [...orders]..sort((a, b) => b.placedAt.compareTo(a.placedAt)),
    );
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
    final supplierGroups = groups.map((g) {
      final subtotal = g.items.fold<int>(
        0,
        (sum, i) => sum + i.unitPriceFcfaSnapshot * i.quantity,
      );
      return OrderSupplierGroup(
        id: IdGenerator.next(),
        supplierId: g.supplierId,
        supplierName: g.supplierName,
        items: g.items,
        deliveryMode: g.deliveryMode,
        deliveryFeeFcfa: g.deliveryMode == DeliveryMode.mtcDelivery
            ? g.mtcDeliveryFeeFcfa
            : 0,
        subtotalFcfa: subtotal,
        status: OrderStatus.pending,
      );
    }).toList();

    final total =
        supplierGroups.fold<int>(
          0,
          (sum, g) => sum + g.subtotalFcfa + g.deliveryFeeFcfa,
        ) +
        (isPriority ? priorityFeeFcfa : 0);

    final order = Order(
      id: IdGenerator.next(),
      clientId: clientId,
      clientDisplayNameSnapshot: clientDisplayNameSnapshot,
      clientPhoneSnapshot: clientPhoneSnapshot,
      supplierGroups: supplierGroups,
      status: OrderStatus.pending,
      placedAt: DateTime.now(),
      totalFcfa: total,
      deliveryAddressLabel: deliveryAddressLabel,
      deliveryCity: deliveryCity,
      deliveryDetails: deliveryDetails,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      fulfillmentMethod: fulfillmentMethod,
      courierPhone: courierPhone,
      alternatePhone: alternatePhone,
      deliveryDate: deliveryDate,
      deliveryTimeSlotLabel: deliveryTimeSlotLabel,
      isPriority: isPriority,
      priorityFeeFcfa: isPriority ? priorityFeeFcfa : 0,
      supplierMessageType: supplierMessageType,
      supplierMessageText: supplierMessageText,
      supplierMessageVoicePath: supplierMessageVoicePath,
      supplierMessageVoiceDurationSeconds: supplierMessageVoiceDurationSeconds,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      mobileMoneyProvider: mobileMoneyProvider,
    );

    _datasource.add(order);
    return order;
  }

  @override
  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
    String? cancellationReason,
    CancelledBy? cancelledBy,
  }) async {
    _datasource.updateGroupStatus(
      orderId,
      groupId,
      status,
      cancellationReason: cancellationReason,
      cancelledBy: cancelledBy,
    );
  }

  @override
  Future<void> attachSupplierVoiceMessage({
    required String orderId,
    required String voicePath,
    required int durationSeconds,
  }) async {
    _datasource.setVoiceMessage(orderId, voicePath, durationSeconds);
  }
}
