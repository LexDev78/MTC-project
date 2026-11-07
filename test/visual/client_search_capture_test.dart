import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_history_screen.dart';
import 'package:mtc_app/features/catalog/presentation/screens/search_screen.dart';
import 'package:mtc_app/features/recommendations/domain/entities/recent_search.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// Le catalogue de démonstration, cherché comme la base le ferait (accents
/// et casse mis de côté).
class _Produits implements ProductRepository {
  @override
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  }) => Stream.value([
    for (final p in catalogueDemo())
      if (query == null || matchesAnySearch([p.name, p.supplierName], query)) p,
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recommandations implements RecommendationRepository {
  @override
  Future<void> logSearch(String query) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<RecentSearch> _recentes() => [
  (query: 'Bogolan indigo', searchedAt: maintenant.subtract(const Duration(minutes: 5))),
  (query: 'Miel de Kita', searchedAt: maintenant.subtract(const Duration(hours: 2))),
  (query: 'Panneau solaire', searchedAt: maintenant.subtract(const Duration(days: 1))),
  (query: 'Riz 25 kg', searchedAt: maintenant.subtract(const Duration(days: 1, hours: 3))),
  (query: 'Masque dogon', searchedAt: maintenant.subtract(const Duration(days: 4))),
];

List<Override> _donnees() => [
  productRepositoryProvider.overrideWithValue(_Produits()),
  recommendationRepositoryProvider.overrideWithValue(_Recommandations()),
  recentSearchesProvider.overrideWith((ref) async => _recentes()),
];

Future<void> _taper(WidgetTester tester, String texte, {bool valider = false}) async {
  await tester.enterText(find.byType(EditableText), texte);
  await tester.pump(const Duration(milliseconds: 350));
  if (valider) {
    await tester.testTextInput.receiveAction(TextInputAction.search);
  }
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  capturerEcran('recherche', () => const SearchScreen(), overrides: _donnees);
  capturerEcran(
    'recherche_suggestions',
    () => const SearchScreen(),
    overrides: _donnees,
    geste: (tester) => _taper(tester, 'bog'),
  );
  capturerEcran(
    'recherche_resultats',
    () => const SearchScreen(),
    overrides: _donnees,
    geste: (tester) => _taper(tester, 'solaire', valider: true),
  );
  capturerEcran(
    'recherche_aucun_resultat',
    () => const SearchScreen(),
    overrides: _donnees,
    geste: (tester) => _taper(tester, 'tracteur', valider: true),
  );
  capturerEcran(
    'historique',
    () => const SearchHistoryScreen(),
    overrides: _donnees,
  );
}
