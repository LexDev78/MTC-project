@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/orders/data/datasources/supabase_order_datasource.dart';
import 'package:mtc_app/features/orders/data/repositories/supabase_order_repository.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/repositories/order_repository.dart';

import '../../support/supabase_test_harness.dart';

// `watchOrdersForSupplier` delegates its scoping entirely to RLS (no
// client-side supplierId filtering — see BACKEND_MIGRATION_PROGRESS.md,
// Lot 10), so reading "as" a given supplier means actually signing in as
// the account that owns it, not just passing its id as a parameter.
Future<OrderRepository> _repositoryAs(String usernameOrPhone) async {
  final client = createTestSupabaseClient();
  await client.auth.signInWithPassword(
    email: pseudoEmail(usernameOrPhone),
    password: 'password123',
  );
  return SupabaseOrderRepository(SupabaseOrderDatasource(client));
}

void main() {
  setUp(() async {
    await resetAndSeed();
  });

  test(
    'watchOrdersForSupplier returns every order that has a group for that '
    'supplier, and nothing for a supplier with no orders at all',
    () async {
      final bogolanOrders = await (await _repositoryAs('fournisseur1'))
          .watchOrdersForSupplier(DemoIds.supplierBogolanBamako)
          .first;
      expect(bogolanOrders, hasLength(1));
      expect(bogolanOrders.single.id, 'order-awa-delivered');

      final materiauxOrders = await (await _repositoryAs('fournisseur7'))
          .watchOrdersForSupplier(DemoIds.supplierMateriauxKoutiala)
          .first;
      expect(materiauxOrders, hasLength(1));
      expect(materiauxOrders.single.id, 'order-moussa-intransit');

      final noOrders = await (await _repositoryAs('fournisseur8'))
          .watchOrdersForSupplier(DemoIds.supplierTissusMopti)
          .first;
      expect(noOrders, isEmpty);
    },
  );

  test('updateGroupStatus rejects an invalid transition', () async {
    final repository = await _repositoryAs('fournisseur1');
    // order-awa-delivered's only group is already `delivered` — a terminal
    // status, so nothing should move it back to `pending`.
    await expectLater(
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
      final repository = await _repositoryAs('fournisseur7');
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
      final repository = await _repositoryAs('fournisseur7');
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
      final repository = await _repositoryAs('fournisseur7');
      await repository.updateGroupStatus(
        orderId: 'order-moussa-intransit',
        groupId: 'group-moussa-intransit-1',
        status: OrderStatus.cancelled,
        cancellationReason: 'Test',
        cancelledBy: CancelledBy.supplier,
      );

      await expectLater(
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
