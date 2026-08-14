import 'dart:async';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/order_status_transitions.dart';

/// Seeded with one `delivered` and one `inTransit` order per demo client, so
/// the review flow and live tracking are both reachable immediately after
/// login without needing to place a new order first.
class InMemoryOrderDatasource {
  InMemoryOrderDatasource() {
    _orders.addAll(_seed());
  }

  final List<Order> _orders = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<Order>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<Order>.unmodifiable(_orders));
  }

  Order getById(String id) {
    return _orders.firstWhere(
      (o) => o.id == id,
      orElse: () => throw NotFoundException('Commande introuvable : $id'),
    );
  }

  void add(Order order) {
    _orders.add(order);
    _changesController.add(null);
  }

  void setVoiceMessage(String orderId, String voicePath, int durationSeconds) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex == -1) {
      throw NotFoundException('Commande introuvable : $orderId');
    }
    _orders[orderIndex] = _orders[orderIndex].copyWith(
      supplierMessageVoicePath: voicePath,
      supplierMessageVoiceDurationSeconds: durationSeconds,
    );
    _changesController.add(null);
  }

  void updateGroupStatus(
    String orderId,
    String groupId,
    OrderStatus status, {
    String? cancellationReason,
    CancelledBy? cancelledBy,
  }) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex == -1) {
      throw NotFoundException('Commande introuvable : $orderId');
    }
    final order = _orders[orderIndex];
    final group = order.supplierGroups.firstWhere(
      (g) => g.id == groupId,
      orElse: () =>
          throw NotFoundException('Groupe fournisseur introuvable : $groupId'),
    );
    if (!isValidTransition(group.status, status)) {
      throw ValidationException(
        'Transition invalide : ${group.status.label} → ${status.label}.',
      );
    }

    final updatedGroups = order.supplierGroups.map((g) {
      if (g.id != groupId) return g;
      return g.copyWith(
        status: status,
        cancellationReason: status == OrderStatus.cancelled
            ? cancellationReason
            : null,
        cancelledBy: status == OrderStatus.cancelled ? cancelledBy : null,
      );
    }).toList();
    _orders[orderIndex] = order.copyWith(
      supplierGroups: updatedGroups,
      status: _deriveOverallStatus(updatedGroups),
    );
    _changesController.add(null);
  }

  OrderStatus _deriveOverallStatus(List<OrderSupplierGroup> groups) {
    bool anyIs(OrderStatus status) => groups.any((g) => g.status == status);

    if (groups.every((g) => g.status == OrderStatus.delivered)) {
      return OrderStatus.delivered;
    }
    if (anyIs(OrderStatus.cancelled)) return OrderStatus.cancelled;
    if (anyIs(OrderStatus.inTransit)) return OrderStatus.inTransit;
    if (anyIs(OrderStatus.preparing)) return OrderStatus.preparing;
    if (anyIs(OrderStatus.confirmed)) return OrderStatus.confirmed;
    return OrderStatus.pending;
  }

  List<Order> _seed() {
    final now = DateTime.now();

    OrderItem item(String productId, String name, int price, int qty) {
      return OrderItem(
        productId: productId,
        productNameSnapshot: name,
        unitPriceFcfaSnapshot: price,
        quantity: qty,
      );
    }

    return [
      Order(
        id: 'order-awa-delivered',
        clientId: DemoIds.clientAwa,
        clientDisplayNameSnapshot: 'Awa Traoré',
        clientPhoneSnapshot: '+22370000001',
        status: OrderStatus.delivered,
        placedAt: now.subtract(const Duration(days: 6)),
        totalFcfa: 25000,
        deliveryAddressLabel: 'Domicile',
        deliveryCity: 'Bamako',
        deliveryDetails: 'Hippodrome, Rue 12, Porte 34',
        deliveryLatitude: MalianCity.bamako.coordinates.latitude + 0.01,
        deliveryLongitude: MalianCity.bamako.coordinates.longitude + 0.01,
        supplierGroups: [
          OrderSupplierGroup(
            id: 'group-awa-delivered-1',
            supplierId: DemoIds.supplierBogolanBamako,
            supplierName: 'Bogolan Bamako',
            items: [
              item('product-001', 'Tissu Bogolan traditionnel', 25000, 1),
            ],
            deliveryMode: DeliveryMode.selfDelivery,
            deliveryFeeFcfa: 0,
            subtotalFcfa: 25000,
            status: OrderStatus.delivered,
          ),
        ],
      ),
      Order(
        id: 'order-awa-intransit',
        clientId: DemoIds.clientAwa,
        clientDisplayNameSnapshot: 'Awa Traoré',
        clientPhoneSnapshot: '+22370000001',
        status: OrderStatus.inTransit,
        placedAt: now.subtract(const Duration(hours: 3)),
        totalFcfa: 87000,
        deliveryAddressLabel: 'Domicile',
        deliveryCity: 'Bamako',
        deliveryDetails: 'Hippodrome, Rue 12, Porte 34',
        deliveryLatitude: MalianCity.bamako.coordinates.latitude + 0.01,
        deliveryLongitude: MalianCity.bamako.coordinates.longitude + 0.01,
        supplierGroups: [
          OrderSupplierGroup(
            id: 'group-awa-intransit-1',
            supplierId: DemoIds.supplierElectroBamako,
            supplierName: 'Electro Bamako',
            items: [item('product-011', 'Smartphone Android 64GB', 85000, 1)],
            deliveryMode: DeliveryMode.mtcDelivery,
            deliveryFeeFcfa: 2000,
            subtotalFcfa: 85000,
            status: OrderStatus.inTransit,
          ),
        ],
      ),
      Order(
        id: 'order-moussa-delivered',
        clientId: DemoIds.clientMoussa,
        clientDisplayNameSnapshot: 'Moussa Diarra',
        clientPhoneSnapshot: '+22370000002',
        status: OrderStatus.delivered,
        placedAt: now.subtract(const Duration(days: 4)),
        totalFcfa: 12500,
        deliveryAddressLabel: 'Domicile',
        deliveryCity: 'Bamako',
        deliveryDetails: 'Badalabougou, Porte 45',
        deliveryLatitude: MalianCity.bamako.coordinates.latitude - 0.015,
        deliveryLongitude: MalianCity.bamako.coordinates.longitude - 0.008,
        supplierGroups: [
          OrderSupplierGroup(
            id: 'group-moussa-delivered-1',
            supplierId: DemoIds.supplierAlimentationSegou,
            supplierName: 'Alimentation Ségou',
            items: [item('product-015', 'Riz local 25kg', 12500, 1)],
            deliveryMode: DeliveryMode.selfDelivery,
            deliveryFeeFcfa: 0,
            subtotalFcfa: 12500,
            status: OrderStatus.delivered,
          ),
        ],
      ),
      Order(
        id: 'order-moussa-intransit',
        clientId: DemoIds.clientMoussa,
        clientDisplayNameSnapshot: 'Moussa Diarra',
        clientPhoneSnapshot: '+22370000002',
        status: OrderStatus.inTransit,
        placedAt: now.subtract(const Duration(hours: 1)),
        totalFcfa: 22000,
        deliveryAddressLabel: 'Domicile',
        deliveryCity: 'Bamako',
        deliveryDetails: 'Badalabougou, Porte 45',
        deliveryLatitude: MalianCity.bamako.coordinates.latitude - 0.015,
        deliveryLongitude: MalianCity.bamako.coordinates.longitude - 0.008,
        supplierGroups: [
          OrderSupplierGroup(
            id: 'group-moussa-intransit-1',
            supplierId: DemoIds.supplierMateriauxKoutiala,
            supplierName: 'Matériaux Koutiala',
            items: [item('product-019', 'Ciment (sac 50kg)', 5000, 4)],
            deliveryMode: DeliveryMode.mtcDelivery,
            deliveryFeeFcfa: 2000,
            subtotalFcfa: 20000,
            status: OrderStatus.inTransit,
          ),
        ],
      ),
    ];
  }
}
