@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/ratings/presentation/controllers/review_controller.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
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
    'submitting a review for the pre-seeded delivered order recomputes the supplier and product ratings',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      const supplierId = DemoIds.supplierBogolanBamako;
      final before = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      expect(before.ratingAverage, 4.6);
      expect(before.ratingCount, 132);

      final canReviewBefore = await container
          .read(reviewRepositoryProvider)
          .canReview(
            orderId: DemoIds.orderAwaDelivered,
            supplierGroupId: DemoIds.groupAwaDelivered1,
          );
      expect(canReviewBefore, isTrue);

      final success = await container
          .read(reviewControllerProvider.notifier)
          .submit(
            orderId: DemoIds.orderAwaDelivered,
            supplierGroupId: DemoIds.groupAwaDelivered1,
            supplierId: supplierId,
            stars: 5,
            comment: 'Excellent service, tissu magnifique !',
          );
      expect(success, isTrue);

      final after = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      final expectedAverage = ((4.6 * 132) + 5) / 133;
      expect(after.ratingAverage, closeTo(expectedAverage, 0.0001));
      expect(after.ratingCount, 133);

      // Product.ratingAverage is denormalized from the supplier — it must
      // reflect the same recomputed value, and catalog sort order should
      // pick it up too.
      final products = await container
          .read(productRepositoryProvider)
          .watchProducts(supplierId: supplierId)
          .first;
      expect(products, isNotEmpty);
      for (final product in products) {
        expect(product.ratingAverage, closeTo(expectedAverage, 0.0001));
        expect(product.ratingCount, 133);
      }

      final canReviewAfter = await container
          .read(reviewRepositoryProvider)
          .canReview(
            orderId: DemoIds.orderAwaDelivered,
            supplierGroupId: DemoIds.groupAwaDelivered1,
          );
      expect(canReviewAfter, isFalse);
    },
  );
}
