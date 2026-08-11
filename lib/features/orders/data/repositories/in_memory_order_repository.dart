import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
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
  Future<Order> placeOrder({
    required String clientId,
    required List<CheckoutGroupInput> groups,
    required String deliveryAddressLabel,
    required String deliveryCity,
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,
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

    final total = supplierGroups.fold<int>(
      0,
      (sum, g) => sum + g.subtotalFcfa + g.deliveryFeeFcfa,
    );

    final order = Order(
      id: IdGenerator.next(),
      clientId: clientId,
      supplierGroups: supplierGroups,
      status: OrderStatus.pending,
      placedAt: DateTime.now(),
      totalFcfa: total,
      deliveryAddressLabel: deliveryAddressLabel,
      deliveryCity: deliveryCity,
      deliveryDetails: deliveryDetails,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
    );

    _datasource.add(order);
    return order;
  }

  @override
  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
  }) async {
    _datasource.updateGroupStatus(orderId, groupId, status);
  }
}
