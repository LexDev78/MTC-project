import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/favorites/presentation/providers/favorite_providers.dart';
import 'package:mtc_app/features/favorites/presentation/screens/favorites_screen.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

List<Override> _favoris() => [
  favoriteProductsProvider.overrideWith(
    (ref) async => catalogueDemo().take(5).toList(),
  ),
];

void main() {
  capturerEcran('favoris', () => const FavoritesScreen(), overrides: _favoris);
  capturerEcran(
    'favoris_selection',
    () => const FavoritesScreen(),
    overrides: _favoris,
    geste: (tester) async {
      await tester.tap(find.text('Choisir'));
      await tester.pump();
      await tester.tap(find.byType(ShopProductCard).at(0));
      await tester.pump();
      await tester.tap(find.byType(ShopProductCard).at(3));
      await tester.pump();
    },
  );
  capturerEcran(
    'favoris_vide',
    () => const FavoritesScreen(),
    overrides: () => [
      favoriteProductsProvider.overrideWith((ref) async => const []),
    ],
  );
}
