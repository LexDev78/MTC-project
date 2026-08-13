@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_status.dart';
import 'package:mtc_app/features/catalog/presentation/controllers/supplier_product_controller.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
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

  Future<void> loginAs(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<bool> createSampleProduct() {
    return container
        .read(supplierProductControllerProvider.notifier)
        .createProduct(
          name: 'Nouveau produit',
          description: 'Description du produit.',
          category: ProductCategory.artisanat,
          priceFcfa: 15000,
          stockQuantity: 20,
          weightKg: 1.0,
          city: 'Bamako',
          imageUrls: const [],
          allowsSelfDelivery: true,
          allowsMtcDelivery: true,
          sizes: const [],
          colors: const [],
          region: ProductRegion.mali,
        );
  }

  test(
    'fournisseur1 (verified) creating a product marks it verified and '
    'bumps their own storefront product count',
    () async {
      await loginAs('fournisseur1');
      final before = await container
          .read(supplierRepositoryProvider)
          .getById(DemoIds.supplierBogolanBamako);

      final success = await createSampleProduct();
      expect(success, isTrue);

      final products = await container
          .read(myProductsProvider(DemoIds.supplierBogolanBamako).future);
      final created = products.firstWhere((p) => p.name == 'Nouveau produit');
      expect(created.supplierId, DemoIds.supplierBogolanBamako);
      expect(created.supplierType, SupplierType.tiers);
      expect(created.isSupplierVerified, isTrue);
      expect(created.status, ProductStatus.draft);

      final after = await container
          .read(supplierRepositoryProvider)
          .getById(DemoIds.supplierBogolanBamako);
      expect(after.productCount, before.productCount + 1);
    },
  );

  test(
    'fournisseur3 (unverified) creating a product marks it unverified — it '
    'stays hidden even once activated, until the account itself is verified',
    () async {
      await loginAs('fournisseur3');

      await createSampleProduct();

      final products = await container.read(
        myProductsProvider(DemoIds.supplierCoutureKayes).future,
      );
      final created = products.firstWhere((p) => p.name == 'Nouveau produit');
      expect(created.isSupplierVerified, isFalse);
    },
  );

  test(
    'agent1 (MTC staff) creates products under the shared MTC Officiel '
    'storefront, always verified',
    () async {
      await loginAs('agent1');
      expect(
        container.read(operatingSupplierIdProvider),
        DemoIds.supplierMtcOfficiel,
      );

      final success = await createSampleProduct();
      expect(success, isTrue);

      final products = await container.read(
        myProductsProvider(DemoIds.supplierMtcOfficiel).future,
      );
      final created = products.firstWhere((p) => p.name == 'Nouveau produit');
      expect(created.supplierType, SupplierType.principal);
      expect(created.isSupplierVerified, isTrue);
    },
  );

  test('archiving a product decrements the product count exactly once', () async {
    await loginAs('fournisseur1');
    await createSampleProduct();
    final products = await container.read(
      myProductsProvider(DemoIds.supplierBogolanBamako).future,
    );
    final created = products.firstWhere((p) => p.name == 'Nouveau produit');
    final beforeArchive = await container
        .read(supplierRepositoryProvider)
        .getById(DemoIds.supplierBogolanBamako);

    final controller = container.read(supplierProductControllerProvider.notifier);
    await controller.setStatus(product: created, status: ProductStatus.archived);
    final afterFirstArchive = await container
        .read(supplierRepositoryProvider)
        .getById(DemoIds.supplierBogolanBamako);
    expect(afterFirstArchive.productCount, beforeArchive.productCount - 1);

    // Archiving an already-archived product must not double-decrement.
    final archived = created.copyWith(status: ProductStatus.archived);
    await controller.setStatus(product: archived, status: ProductStatus.archived);
    final afterSecondArchive = await container
        .read(supplierRepositoryProvider)
        .getById(DemoIds.supplierBogolanBamako);
    expect(afterSecondArchive.productCount, afterFirstArchive.productCount);
  });
}
