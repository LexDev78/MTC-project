@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/chat/presentation/providers/chat_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/controllers/supplier_order_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  test(
    "a supplier's order view only ever exposes their own group of a "
    "multi-supplier order — never another supplier's items or prices",
    () async {
      // client2 (Moussa)'s pre-seeded cart spans two different suppliers:
      // Alimentation Ségou (rice) and Electro Bamako (a smartphone) — see
      // stock_decrement_test.dart for the same cart.
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client2', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await container.read(addressesProvider.future);
      await container.read(checkoutGroupsProvider.future);
      await container.read(checkoutControllerProvider.future);

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();
      expect(success, isTrue);
      final placedOrderId = container
          .read(checkoutControllerProvider)
          .valueOrNull!
          .id;

      // `supplierOrdersProvider` derives "my group" from the ACTUAL
      // authenticated session (`operating_supplier_id()`, enforced by RLS),
      // not from the id argument — viewing each supplier's order view for
      // real means actually being logged in as that supplier.
      await container.read(authRepositoryProvider).logout();
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur6', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final riceSupplierViews = await container.read(
        supplierOrdersProvider(DemoIds.supplierAlimentationSegou).future,
      );
      final riceView = riceSupplierViews.firstWhere(
        (v) => v.orderId == placedOrderId,
      );
      expect(riceView.myGroup.items, hasLength(1));
      expect(riceView.myGroup.items.single.productNameSnapshot, 'Riz local 25kg');
      expect(riceView.clientDisplayNameSnapshot, 'Moussa Diarra');

      await container.read(authRepositoryProvider).logout();
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur5', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final phoneSupplierViews = await container.read(
        supplierOrdersProvider(DemoIds.supplierElectroBamako).future,
      );
      final phoneView = phoneSupplierViews.firstWhere(
        (v) => v.orderId == placedOrderId,
      );
      expect(phoneView.myGroup.items, hasLength(1));
      expect(
        phoneView.myGroup.items.single.productNameSnapshot,
        'Smartphone Android 64GB',
      );

      // Neither supplier's own group total leaks into the other's view.
      expect(
        riceView.myGroup.subtotalFcfa,
        isNot(phoneView.myGroup.subtotalFcfa),
      );
    },
  );

  test(
    'supplier cancellation records a reason and the order becomes reachable '
    'as cancelled in that supplier\'s own view',
    () async {
      const supplierId = DemoIds.supplierMateriauxKoutiala;
      // `update_order_group_status()` checks the group belongs to the
      // ACTUAL authenticated session's operating supplier — no session was
      // logged in at all before, so the RPC rejected it as unauthorized.
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur7', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final controller = container.read(
        supplierOrderControllerProvider.notifier,
      );

      final success = await controller.cancel(
        orderId: DemoIds.orderMoussaIntransit,
        groupId: DemoIds.groupMoussaIntransit1,
        reason: 'Camion en panne, impossible de livrer à temps.',
        clientId: DemoIds.clientMoussa,
        supplierName: 'Matériaux Koutiala',
      );
      expect(success, isTrue);

      final views = await container.read(
        supplierOrdersProvider(supplierId).future,
      );
      final view = views.firstWhere((v) => v.orderId == DemoIds.orderMoussaIntransit);
      expect(view.myGroup.status, OrderStatus.cancelled);
      expect(
        view.myGroup.cancellationReason,
        'Camion en panne, impossible de livrer à temps.',
      );
      expect(view.myGroup.cancelledBy, CancelledBy.supplier);
    },
  );

  test(
    'contacting the client from an order starts (or reuses) a conversation '
    "with that specific client, scoped to the supplier's own account",
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final conversationId = await container
          .read(supplierOrderControllerProvider.notifier)
          .contactClient(
            clientId: DemoIds.clientAwa,
            clientDisplayNameSnapshot: 'Awa Traoré',
          );

      expect(conversationId, isNotNull);

      final conversations = await container.read(
        chatRepositoryProvider,
      ).watchConversationsForUser(DemoIds.clientAwa).first;
      expect(
        conversations.any(
          (c) =>
              c.id == conversationId &&
              c.supplierId == DemoIds.supplierBogolanBamako,
        ),
        isTrue,
      );
    },
  );
}
