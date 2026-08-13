import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

Product _productNamed(String name) => Product(
  id: 'product-$name',
  supplierId: 'supplier-test',
  supplierName: 'Fournisseur Test',
  supplierType: SupplierType.tiers,
  name: name,
  description: 'Description.',
  category: ProductCategory.textilesBogolan,
  priceFcfa: 5000,
  stockQuantity: 10,
  imageUrls: const [],
  city: 'Bamako',
  ratingAverage: 4.5,
  ratingCount: 10,
  allowsSelfDelivery: true,
  allowsMtcDelivery: true,
  weightKg: 1.0,
  createdAt: DateTime(2024, 1, 1),
);

Future<Size> _pumpAndMeasureImage(WidgetTester tester, Product product) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              height: 250,
              child: ProductCard(product: product),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(ProductImage));
}

void main() {
  testWidgets(
    'a one-line title and a two-line title leave the product photo the '
    'same size, so cards in the same row/grid line up',
    (tester) async {
      final shortTitleImageSize = await _pumpAndMeasureImage(
        tester,
        _productNamed('Sac'),
      );
      final longTitleImageSize = await _pumpAndMeasureImage(
        tester,
        _productNamed(
          'Tissu bogolan traditionnel tissé et teint à la main, très long nom',
        ),
      );

      expect(longTitleImageSize.height, shortTitleImageSize.height);
    },
  );
}
