@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';

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

  // `cart_items` is owner-only under RLS — every test below acts on its
  // own cart, so it must actually be that user's session, not the
  // anonymous client `createTestSupabaseClient()` starts with.
  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'client2 (Moussa) has a pre-seeded cart totalling 110 000 FCFA',
    () async {
      await login('client2');
      final items = await container
          .read(cartRepositoryProvider)
          .watchCart(DemoIds.clientMoussa)
          .first;

      expect(items, hasLength(2));
      final total = items.fold<int>(
        0,
        (sum, i) => sum + i.unitPriceFcfaSnapshot * i.quantity,
      );
      expect(total, 110000);
    },
  );

  test(
    'adding the same product twice increments quantity instead of duplicating',
    () async {
      await login('client1');
      final repository = container.read(cartRepositoryProvider);

      await repository.addItem(
        userId: DemoIds.clientAwa,
        productId: 'product-001',
        supplierId: DemoIds.supplierBogolanBamako,
        productName: 'Tissu Bogolan traditionnel',
        unitPriceFcfa: 25000,
        quantity: 1,
      );
      await repository.addItem(
        userId: DemoIds.clientAwa,
        productId: 'product-001',
        supplierId: DemoIds.supplierBogolanBamako,
        productName: 'Tissu Bogolan traditionnel',
        unitPriceFcfa: 25000,
        quantity: 2,
      );

      final items = await repository.watchCart(DemoIds.clientAwa).first;
      expect(items, hasLength(1));
      expect(items.single.quantity, 3);
    },
  );

  test('removing an item drops it from the cart', () async {
    await login('client2');
    final repository = container.read(cartRepositoryProvider);
    final items = await repository.watchCart(DemoIds.clientMoussa).first;

    await repository.removeItem(
      userId: DemoIds.clientMoussa,
      cartItemId: items.first.id,
    );

    final updated = await repository.watchCart(DemoIds.clientMoussa).first;
    expect(updated, hasLength(1));
  });
}
