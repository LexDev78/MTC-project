import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
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

    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    await container.read(checkoutGroupsProvider.future);
    // Lets `CheckoutController.build()` (a trivial `async => null`) settle
    // before any test synchronously sets `state` — otherwise the pending
    // initial build can resolve afterward and clobber it back to
    // `AsyncData(null)`.
    await container.read(checkoutControllerProvider.future);
  });

  test(
    'placing an order in pickup-point mode without picking a point fails '
    'with a validation error',
    () async {
      container.read(fulfillmentMethodProvider.notifier).state =
          FulfillmentMethod.pickupPoint;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isFalse);
      expect(
        container.read(checkoutControllerProvider).error,
        isA<ValidationException>(),
      );
    },
  );

  test(
    'placing an order in pickup-point mode after picking a point succeeds '
    'and records that point as the delivery destination',
    () async {
      container.read(fulfillmentMethodProvider.notifier).state =
          FulfillmentMethod.pickupPoint;
      final point = container.read(pickupPointsProvider).first;
      container.read(selectedPickupPointProvider.notifier).state = point;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order, isNotNull);
      expect(order!.fulfillmentMethod, FulfillmentMethod.pickupPoint);
      expect(order.deliveryAddressLabel, point.name);
      expect(order.courierPhone, isNull);
    },
  );

  test(
    'pickup-point mode forces MTC delivery for every group, even one the '
    'client had previously set to self-delivery',
    () async {
      // The Electro Bamako group (smartphone) allows both self and MTC
      // delivery — explicitly pick self first, as if set while still in
      // home-delivery mode.
      container
          .read(deliveryModeChoiceProvider(DemoIds.supplierElectroBamako).notifier)
          .state = DeliveryMode.selfDelivery;

      container.read(fulfillmentMethodProvider.notifier).state =
          FulfillmentMethod.pickupPoint;
      container.read(selectedPickupPointProvider.notifier).state =
          container.read(pickupPointsProvider).first;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      final electroGroup = order!.supplierGroups.firstWhere(
        (g) => g.supplierId == DemoIds.supplierElectroBamako,
      );
      expect(electroGroup.deliveryMode, DeliveryMode.mtcDelivery);
    },
  );

  test(
    'a priority home-delivery order carries the priority fee in its total',
    () async {
      container.read(isPriorityOrderProvider.notifier).state = true;

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();

      expect(success, isTrue);
      final order = container.read(checkoutControllerProvider).valueOrNull;
      expect(order, isNotNull);
      expect(order!.fulfillmentMethod, FulfillmentMethod.homeDelivery);
      expect(order.isPriority, isTrue);
      expect(order.priorityFeeFcfa, priorityOrderFeeFcfa);
      expect(order.courierPhone, isNotEmpty);
    },
  );
}
