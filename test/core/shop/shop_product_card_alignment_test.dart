import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/shop/shop.dart';

ShopProductData _article(String titre) => ShopProductData(
  imagePath: null,
  brand: 'Bogolan Bamako',
  title: titre,
  priceFcfa: 5000,
);

Future<Size> _photo(WidgetTester tester, String titre) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ShopScope(
        child: Scaffold(
          body: Center(
            child: ShopProductCard(data: _article(titre), onTap: () {}),
          ),
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(ShopProductImage));
}

// Repris de l'ancienne carte produit : dans une grille, deux cartes voisines
// doivent s'aligner, quelle que soit la longueur de leur titre.
void main() {
  testWidgets('un titre d\'une ligne et un titre de deux lignes laissent la '
      'photo à la même taille', (tester) async {
    final courte = await _photo(tester, 'Sac');
    final longue = await _photo(
      tester,
      'Tissu bogolan traditionnel tissé et teint à la main, très long nom',
    );

    expect(longue, courte);
    expect(tester.takeException(), isNull);
  });
}
