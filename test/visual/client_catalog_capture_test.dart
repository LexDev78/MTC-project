import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/product_list_filters.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/catalogue_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/category_products_screen.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_filter_sheet.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

List<Override> _donnees() {
  const categorie = ProductCategory.electronique;
  final liste = catalogueDemo().where((p) => p.category == categorie).toList();
  return [
    categoryAllProductsProvider(
      categorie,
    ).overrideWith((ref) => Stream.value(liste)),
  ];
}

/// La feuille sur tout le catalogue de démonstration, comme la recherche
/// l'ouvre : l'axe « Catégorie » y figure.
Widget _feuille() => Scaffold(
  body: SafeArea(
    child: ProductFilterSheet(
      products: catalogueDemo(),
      initial: const ProductListFilters(inStockOnly: true),
    ),
  ),
);

Future<void> _ouvrir(WidgetTester tester, String ligne) async {
  await tester.tap(find.text(ligne));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  capturerEcran('decouvrir', () => const CatalogueScreen());
  capturerEcran(
    'categorie',
    () => const CategoryProductsScreen(category: ProductCategory.electronique),
    overrides: _donnees,
    hauteur: 1100,
  );
  capturerEcran('filtre', _feuille);
  capturerEcran(
    'filtre_tri',
    _feuille,
    geste: (tester) => _ouvrir(tester, 'Trier'),
  );
  capturerEcran(
    'filtre_categorie',
    _feuille,
    geste: (tester) => _ouvrir(tester, 'Catégorie'),
  );
  capturerEcran(
    'filtre_prix',
    _feuille,
    geste: (tester) => _ouvrir(tester, 'Prix'),
  );
}
