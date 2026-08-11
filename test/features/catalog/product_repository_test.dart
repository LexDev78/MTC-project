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

  test('filters by supplier type', () async {
    final principalProducts = await repository
        .watchProducts(supplierType: SupplierType.principal)
        .first;

    expect(principalProducts, isNotEmpty);
    expect(
      principalProducts.every((p) => p.supplierType == SupplierType.principal),
      isTrue,
    );
  });

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
