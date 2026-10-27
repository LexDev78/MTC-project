@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
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

    // client2 (Moussa) — pre-seeded cart: 2x "Riz local 25kg" (product-015,
    // stock 200) + 1x "Smartphone Android 64GB" (product-011, stock 30).
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    await container.read(checkoutGroupsProvider.future);
    // Lets `CheckoutController.build()` settle before the test synchronously
    // sets `state` — see `fulfillment_method_test.dart` for the same wait.
    await container.read(checkoutControllerProvider.future);
  });

  test(
    "placing an order decrements each purchased product's stock by its "
    'cart quantity and logs a sale movement for each line',
    () async {
      final productRepository = container.read(productRepositoryProvider);
      final riceBefore = await productRepository.getById(DemoIds.product015);
      final phoneBefore = await productRepository.getById(DemoIds.product011);
      expect(riceBefore.stockQuantity, 200);
      expect(phoneBefore.stockQuantity, 30);

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();
      expect(success, isTrue);

      final riceAfter = await productRepository.getById(DemoIds.product015);
      final phoneAfter = await productRepository.getById(DemoIds.product011);
      expect(riceAfter.stockQuantity, 198); // 200 - 2
      expect(phoneAfter.stockQuantity, 29); // 30 - 1

      // `stock_movements` is the owning supplier's private ledger — client2
      // didn't sell the rice, so RLS wouldn't let them read it back via the
      // normal repository; the admin backdoor is for this assertion only.
      final riceMovements = await fetchStockMovementsAsAdmin(DemoIds.product015);
      expect(riceMovements, hasLength(1));
      expect(riceMovements.single['quantity_delta'], -2);
      expect(riceMovements.single['reason'], 'sale');
    },
  );

  test(
    'a line that exceeds available stock blocks the whole order — no order '
    'is created and no line is even partially decremented',
    () async {
      final productRepository = container.read(productRepositoryProvider);
      // Bring the smartphone's stock below the cart's requested quantity
      // (1) so this checkout is expected to fail on that line. Client2
      // doesn't own this product (Electro Bamako does, and has no login
      // account in the seed data at all), so this must go through the
      // admin backdoor rather than `productRepository.adjustStock` —
      // real RLS would otherwise (rightly) reject it.
      await adjustStockAsAdmin(productId: DemoIds.product011, quantityDelta: -30);
      final phoneBefore = await productRepository.getById(DemoIds.product011);
      expect(phoneBefore.stockQuantity, 0);

      final ordersBefore = await container
          .read(orderRepositoryProvider)
          .watchOrdersForUser(DemoIds.clientMoussa)
          .first;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isFalse);
      expect(
        container.read(checkoutControllerProvider).error,
        isA<InsufficientStockException>(),
      );

      // The rice line was perfectly valid on its own — it must stay
      // untouched because validation happens for every line before any
      // line is written.
      final riceAfter = await productRepository.getById(DemoIds.product015);
      expect(riceAfter.stockQuantity, 200);

      final ordersAfter = await container
          .read(orderRepositoryProvider)
          .watchOrdersForUser(DemoIds.clientMoussa)
          .first;
      expect(ordersAfter.length, ordersBefore.length);
    },
  );
}
