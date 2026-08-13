import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/catalog/data/datasources/in_memory_product_datasource.dart';
import 'package:mtc_app/features/catalog/data/repositories/in_memory_product_repository.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

void main() {
  late InMemoryProductRepository repository;

  setUp(() {
    repository = InMemoryProductRepository(InMemoryProductDatasource());
  });

  test('hides products from unverified/pending tiers suppliers', () async {
    final products = await repository.watchProducts().first;

    expect(products.any((p) => p.supplierName == 'Artisanat Sikasso'), isFalse);
  });

  test('sorts visible products by supplier rating, highest first', () async {
    final products = await repository.watchProducts().first;

    for (var i = 0; i < products.length - 1; i++) {
      expect(
        products[i].ratingAverage,
        greaterThanOrEqualTo(products[i + 1].ratingAverage),
      );
    }
  });

  test('tiers filter returns only third-party products', () async {
    final tiersProducts = await repository
        .watchProducts(supplierType: SupplierType.tiers)
        .first;

    expect(tiersProducts, isNotEmpty);
    expect(
      tiersProducts.every((p) => p.supplierType == SupplierType.tiers),
      isTrue,
    );
  });

  test(
    'principal filter aggregates every verified product, tiers included',
    () async {
      final allProducts = await repository.watchProducts().first;
      final principalProducts = await repository
          .watchProducts(supplierType: SupplierType.principal)
          .first;

      expect(principalProducts, hasLength(allProducts.length));
      expect(
        principalProducts.any((p) => p.supplierType == SupplierType.tiers),
        isTrue,
      );
      // Tiers products keep their original supplier attribution — the
      // aggregation only changes catalog *visibility*, not ownership.
      expect(
        principalProducts
            .firstWhere((p) => p.supplierName == 'Bogolan Bamako')
            .supplierType,
        SupplierType.tiers,
      );
    },
  );

  test('filters by category', () async {
    final products = await repository
        .watchProducts(category: ProductCategory.alimentation)
        .first;

    expect(products, isNotEmpty);
    expect(
      products.every((p) => p.category == ProductCategory.alimentation),
      isTrue,
    );
  });

  test('filters by free-text query across name/description/supplier', () async {
    final products = await repository.watchProducts(query: 'riz').first;

    expect(products, isNotEmpty);
    expect(
      products.every(
        (p) =>
            p.name.toLowerCase().contains('riz') ||
            p.description.toLowerCase().contains('riz') ||
            p.supplierName.toLowerCase().contains('riz'),
      ),
      isTrue,
    );
  });
}
