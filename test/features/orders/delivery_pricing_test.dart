import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/orders/domain/delivery_pricing.dart';

void main() {
  test('the cheapest possible delivery is exactly the 1000 FCFA floor', () {
    final fee = computeHomeDeliveryFeeFcfa(
      distanceKm: 0,
      totalWeightKg: 0,
      categories: const {},
    );

    expect(fee, 1000);
  });

  test('an extreme distance/weight/category never exceeds the 4000 FCFA cap', () {
    final fee = computeHomeDeliveryFeeFcfa(
      distanceKm: 5000,
      totalWeightKg: 1000,
      categories: const {ProductCategory.materiauxConstruction},
    );

    expect(fee, 4000);
  });

  test('fee never drops below the 1000 FCFA floor even with negligible inputs', () {
    final fee = computeHomeDeliveryFeeFcfa(
      distanceKm: 0.001,
      totalWeightKg: 0.001,
      categories: const {ProductCategory.textilesBogolan},
    );

    expect(fee, greaterThanOrEqualTo(1000));
  });

  test('a farther delivery costs more than a nearby one, all else equal', () {
    final near = computeHomeDeliveryFeeFcfa(
      distanceKm: 2,
      totalWeightKg: 1,
      categories: const {ProductCategory.electronique},
    );
    final far = computeHomeDeliveryFeeFcfa(
      distanceKm: 50,
      totalWeightKg: 1,
      categories: const {ProductCategory.electronique},
    );

    expect(far, greaterThan(near));
  });

  test('a heavier order costs more than a lighter one, all else equal', () {
    final light = computeHomeDeliveryFeeFcfa(
      distanceKm: 10,
      totalWeightKg: 1,
      categories: const {ProductCategory.alimentation},
    );
    final heavy = computeHomeDeliveryFeeFcfa(
      distanceKm: 10,
      totalWeightKg: 40,
      categories: const {ProductCategory.alimentation},
    );

    expect(heavy, greaterThan(light));
  });

  test(
    'bulky construction materials cost more to move than light textiles, '
    'all else equal',
    () {
      final textiles = computeHomeDeliveryFeeFcfa(
        distanceKm: 10,
        totalWeightKg: 1,
        categories: const {ProductCategory.textilesBogolan},
      );
      final materials = computeHomeDeliveryFeeFcfa(
        distanceKm: 10,
        totalWeightKg: 1,
        categories: const {ProductCategory.materiauxConstruction},
      );

      expect(materials, greaterThan(textiles));
    },
  );

  test(
    'a mixed-category cart is priced by its costliest category, not the sum',
    () {
      final mixed = computeHomeDeliveryFeeFcfa(
        distanceKm: 10,
        totalWeightKg: 1,
        categories: const {
          ProductCategory.textilesBogolan,
          ProductCategory.materiauxConstruction,
        },
      );
      final materialsOnly = computeHomeDeliveryFeeFcfa(
        distanceKm: 10,
        totalWeightKg: 1,
        categories: const {ProductCategory.materiauxConstruction},
      );

      expect(mixed, materialsOnly);
    },
  );
}
