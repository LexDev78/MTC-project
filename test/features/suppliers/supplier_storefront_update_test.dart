@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/controllers/supplier_account_controller.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

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
    'SupplierRepository.updateStorefront replaces every editable field at '
    'once, and setOpen flips isOpen independently',
    () async {
      // Writing to `suppliers` requires an authenticated owner session —
      // RLS (see BACKEND_MIGRATION_PROGRESS.md, Lot 3/4) — even when
      // calling the repository directly rather than through the
      // controller.
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final repo = container.read(supplierRepositoryProvider);

      await repo.updateStorefront(
        supplierId: DemoIds.supplierBogolanBamako,
        description: 'Tissus traditionnels tissés main.',
        bannerUrl: '/tmp/banner.jpg',
        fullAddress: 'Marché de Médine, Bamako',
        addressLatitude: 12.6,
        addressLongitude: -8.0,
        publicPhoneNumbers: const ['+22370000000', '+22370000001'],
        deliveryZones: const ['Bamako', 'Kati'],
        openingHoursLabel: 'Lun-Sam 8h-18h',
      );

      final updated = await repo.getById(DemoIds.supplierBogolanBamako);
      expect(updated.description, 'Tissus traditionnels tissés main.');
      expect(updated.fullAddress, 'Marché de Médine, Bamako');
      expect(updated.publicPhoneNumbers, ['+22370000000', '+22370000001']);
      expect(updated.deliveryZones, ['Bamako', 'Kati']);
      expect(updated.openingHoursLabel, 'Lun-Sam 8h-18h');
      expect(updated.isOpen, isTrue); // untouched by updateStorefront

      await repo.setOpen(supplierId: DemoIds.supplierBogolanBamako, isOpen: false);
      final closed = await repo.getById(DemoIds.supplierBogolanBamako);
      expect(closed.isOpen, isFalse);
      // updateStorefront fields survive a setOpen call untouched.
      expect(closed.description, 'Tissus traditionnels tissés main.');
    },
  );

  test(
    'SupplierAccountController.updateStorefront resolves the operating '
    "supplier and derives coordinates from the supplier's city — the "
    'caller never passes either',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(supplierAccountControllerProvider.notifier)
          .updateStorefront(
            description: 'Nouvelle description.',
            bannerUrl: null,
            fullAddress: 'Rue 123, Bamako',
            publicPhoneNumbers: const ['+22370000002'],
            deliveryZones: const ['Bamako'],
            openingHoursLabel: null,
          );
      expect(ok, isTrue);

      final updated = await container
          .read(supplierRepositoryProvider)
          .getById(DemoIds.supplierBogolanBamako);
      expect(updated.description, 'Nouvelle description.');
      expect(updated.addressLatitude, MalianCity.bamako.coordinates.latitude);
      expect(
        updated.addressLongitude,
        MalianCity.bamako.coordinates.longitude,
      );
    },
  );

  test(
    'SupplierAccountController.setOpen resolves the operating supplier '
    'automatically',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(supplierAccountControllerProvider.notifier)
          .setOpen(false);
      expect(ok, isTrue);

      final updated = await container
          .read(supplierRepositoryProvider)
          .getById(DemoIds.supplierBogolanBamako);
      expect(updated.isOpen, isFalse);
    },
  );
}
