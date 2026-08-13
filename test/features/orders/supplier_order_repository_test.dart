import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/orders/data/datasources/in_memory_order_datasource.dart';
import 'package:mtc_app/features/orders/data/repositories/in_memory_order_repository.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';

void main() {
  late InMemoryOrderRepository repository;

  setUp(() {
    repository = InMemoryOrderRepository(InMemoryOrderDatasource());
  });

  test(
    'watchOrdersForSupplier returns every order that has a group for that '
    'supplier, and nothing for a supplier with no orders at all',
    () async {
      final bogolanOrders = await repository
          .watchOrdersForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      expect(bogolanOrders, hasLength(1));
      expect(bogolanOrders.single.id, 'order-awa-delivered');

      final materiauxOrders = await repository
          .watchOrdersForSupplier(DemoIds.supplierMateriauxKoutiala)
          .first;
      expect(materiauxOrders, hasLength(1));
      expect(materiauxOrders.single.id, 'order-moussa-intransit');

      final noOrders = await repository
          .watchOrdersForSupplier(DemoIds.supplierTissusMopti)
          .first;
      expect(noOrders, isEmpty);
    },
  );

  test('updateGroupStatus rejects an invalid transition', () async {
    // order-awa-delivered's only group is already `delivered` — a terminal
    // status, so nothing should move it back to `pending`.
    expect(
      () => repository.updateGroupStatus(
        orderId: 'order-awa-delivered',
        groupId: 'group-awa-delivered-1',
        status: OrderStatus.pending,
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test(
    'updateGroupStatus applies a valid transition and recomputes the '
    "order's overall status",
    () async {
      await repository.updateGroupStatus(
        orderId: 'order-moussa-intransit',
        groupId: 'group-moussa-intransit-1',
        status: OrderStatus.delivered,
      );

      final order = await repository.watchOrderById('order-moussa-intransit').first;
      expect(order.supplierGroups.single.status, OrderStatus.delivered);
      // The only group is delivered, so the whole order is too.
      expect(order.status, OrderStatus.delivered);
    },
  );

  test(
    'cancelling records the reason and who cancelled, and clears them if '
    'the same group is (hypothetically) re-derived later',
    () async {
      await repository.updateGroupStatus(
        orderId: 'order-moussa-intransit',
        groupId: 'group-moussa-intransit-1',
        status: OrderStatus.cancelled,
        cancellationReason: 'Rupture de stock imprévue.',
        cancelledBy: CancelledBy.supplier,
      );

      final order = await repository.watchOrderById('order-moussa-intransit').first;
      final group = order.supplierGroups.single;
      expect(group.status, OrderStatus.cancelled);
      expect(group.cancellationReason, 'Rupture de stock imprévue.');
      expect(group.cancelledBy, CancelledBy.supplier);
      expect(order.status, OrderStatus.cancelled);
    },
  );

  test(
    'a cancelled group cannot be cancelled again, or moved anywhere else',
    () async {
      await repository.updateGroupStatus(
        orderId: 'order-moussa-intransit',
        groupId: 'group-moussa-intransit-1',
        status: OrderStatus.cancelled,
        cancellationReason: 'Test',
        cancelledBy: CancelledBy.supplier,
      );

      expect(
        () => repository.updateGroupStatus(
          orderId: 'order-moussa-intransit',
          groupId: 'group-moussa-intransit-1',
          status: OrderStatus.delivered,
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );
}
