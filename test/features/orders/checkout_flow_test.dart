import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  test(
    'client2 checking out their pre-seeded cart creates a pending order and empties the cart',
    () async {
      // Log in as client2 so currentUserProvider / defaultAddressProvider
      // resolve to Moussa's account.
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client2', password: 'password123');
      await container.read(currentUserProvider.future);
      // Let currentUserProvider settle to the logged-in user.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        container.read(currentUserProvider).valueOrNull,
        isA<ClientUser>(),
      );

      await container.read(addressesProvider.future);
      final address = container.read(defaultAddressProvider);
      expect(address, isNotNull);

      final groups = await container.read(checkoutGroupsProvider.future);
      expect(groups, isNotEmpty);

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();
      expect(success, isTrue);

      final placedOrder = container
          .read(checkoutControllerProvider)
          .valueOrNull;
      expect(placedOrder, isNotNull);
      expect(placedOrder!.status, OrderStatus.pending);
      expect(placedOrder.totalFcfa, greaterThan(0));

      final cartAfter = await container
          .read(cartRepositoryProvider)
          .watchCart(DemoIds.clientMoussa)
          .first;
      expect(cartAfter, isEmpty);

      final orders = await container
          .read(orderRepositoryProvider)
          .watchOrdersForUser(DemoIds.clientMoussa)
          .first;
      // 2 pre-seeded + the newly placed one.
      expect(orders.length, 3);
    },
  );
}
