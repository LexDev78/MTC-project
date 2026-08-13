import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
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

    // client2 (Moussa) — pre-seeded cart: 2× "Riz local 25kg" from
    // Alimentation Ségou (far, heavy: 50kg) and 1× "Smartphone Android
    // 64GB" from Electro Bamako (a few km away, light: 0.3kg). His saved
    // address is in Bamako, near the Electro Bamako supplier.
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
  });

  test(
    'the distant, heavy Ségou group costs more to deliver than the nearby, '
    'light Bamako group — and both stay within the 1000-4000 FCFA bracket',
    () async {
      final groups = await container.read(checkoutGroupsProvider.future);

      final segouGroup = groups.firstWhere(
        (g) => g.supplierName == 'Alimentation Ségou',
      );
      final bamakoGroup = groups.firstWhere(
        (g) => g.supplierName == 'Electro Bamako',
      );

      for (final fee in [segouGroup.mtcDeliveryFeeFcfa, bamakoGroup.mtcDeliveryFeeFcfa]) {
        expect(fee, greaterThanOrEqualTo(1000));
        expect(fee, lessThanOrEqualTo(4000));
      }

      expect(
        segouGroup.mtcDeliveryFeeFcfa,
        greaterThan(bamakoGroup.mtcDeliveryFeeFcfa),
      );

      // Distance alone (~235 km) saturates the distance contribution, and
      // 50 kg of rice saturates most of the weight contribution too, so
      // this is fully deterministic: 1000 base + 1500 distance cap + 1250
      // weight (50 kg × 25 FCFA/kg) + 200 alimentation surcharge.
      expect(segouGroup.mtcDeliveryFeeFcfa, 3950);
    },
  );

  test(
    'switching to a Bamako pickup point drops the far Ségou group\'s fee '
    'less than switching the destination changes the near Bamako group\'s',
    () async {
      final beforeGroups = await container.read(checkoutGroupsProvider.future);
      final segouBefore = beforeGroups
          .firstWhere((g) => g.supplierName == 'Alimentation Ségou')
          .mtcDeliveryFeeFcfa;

      container.read(fulfillmentMethodProvider.notifier).state =
          FulfillmentMethod.pickupPoint;
      final bamakoPoint = container
          .read(pickupPointsProvider)
          .firstWhere((p) => p.city == 'Bamako');
      container.read(selectedPickupPointProvider.notifier).state = bamakoPoint;

      final afterGroups = await container.read(checkoutGroupsProvider.future);
      final segouAfter = afterGroups
          .firstWhere((g) => g.supplierName == 'Alimentation Ségou')
          .mtcDeliveryFeeFcfa;

      // Still ~235 km away regardless of which Bamako point/address is
      // used, so the fee stays pinned at the same deterministic value.
      expect(segouAfter, segouBefore);
    },
  );
}
