import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/utils/search_text.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/product_list_filters.dart';

import '../../support/shop_fixtures.dart';

void main() {
  group('ProductListFilters', () {
    final catalogue = catalogueDemo();

    test('trie et borne sur le prix affiché, remise comprise', () {
      // Le panneau coûte 65 000 F, affiché 55 250 F sous sa remise de 15 %.
      final tries = const ProductListFilters(
        sort: ProductSortOption.priceDesc,
      ).apply(catalogue);
      expect(tries.first.id, 'panneau');
      expect(ProductListFilters.displayedPrice(tries.first), 55250);

      final jusqua = const ProductListFilters(
        maxPriceFcfa: 55250,
      ).apply(catalogue).map((p) => p.id);
      expect(jusqua, contains('panneau'));
      expect(displayedPriceBounds(catalogue), (4500, 55250));
    });

    test('le tri par nom ignore accents et casse, et le tri est stable', () {
      final noms = const ProductListFilters(
        sort: ProductSortOption.nameAsc,
      ).apply(catalogue).map((p) => p.name).toList();
      expect(noms.first, 'Masque dogon sculpté');
      expect(noms.last, 'Tôle ondulée, le lot de 10');

      // À note égale, l'ordre d'arrivée reste.
      final egaux = [
        produit(
          id: 'a',
          nom: 'A',
          boutique: 'X',
          photo: 'p',
          categorie: ProductCategory.autre,
          prix: 1,
          note: 4,
        ),
        produit(
          id: 'b',
          nom: 'B',
          boutique: 'X',
          photo: 'p',
          categorie: ProductCategory.autre,
          prix: 1,
          note: 4,
        ),
        produit(
          id: 'c',
          nom: 'C',
          boutique: 'X',
          photo: 'p',
          categorie: ProductCategory.autre,
          prix: 1,
          note: 5,
        ),
      ];
      expect(
        const ProductListFilters(
          sort: ProductSortOption.ratingDesc,
        ).apply(egaux).map((p) => p.id),
        ['c', 'a', 'b'],
      );
    });

    test('catégories, boutiques et stock se combinent', () {
      final filtres = const ProductListFilters(
        categories: {ProductCategory.electronique},
        supplierIds: {'f-MTC Officiel'},
        inStockOnly: true,
      );
      final avecRupture = [
        ...catalogue,
        produit(
          id: 'epuise',
          nom: 'Radio épuisée',
          boutique: 'MTC Officiel',
          photo: 'p',
          categorie: ProductCategory.electronique,
          prix: 9000,
          stock: 0,
        ),
      ];
      expect(filtres.apply(avecRupture).map((p) => p.id), ['panneau', 'radio']);
      expect(filtres.hasFilter, isTrue);
      expect(const ProductListFilters().isActive, isFalse);
      expect(
        const ProductListFilters(sort: ProductSortOption.newest).hasFilter,
        isFalse,
      );
    });

    test('deux réglages identiques sont égaux, ensembles compris', () {
      expect(
        const ProductListFilters(categories: {ProductCategory.artisanat}),
        const ProductListFilters(categories: {ProductCategory.artisanat}),
      );
      expect(
        const ProductListFilters().withPriceRange(1000, null),
        isNot(const ProductListFilters()),
      );
    });
  });

  group('searchMatchRange', () {
    test('situe la partie trouvée dans le texte d\'origine', () {
      expect(searchMatchRange('Tissu bògòlan', 'bogo'), (6, 10));
      expect(searchMatchRange('Bogolan indigo', 'BOG'), (0, 3));
      expect(searchMatchRange('Riz', 'mil'), isNull);
      expect(searchMatchRange('Riz', '  '), isNull);
    });

    test('ne se décale pas après une lettre qui se replie en deux', () {
      // « œ » se replie en « oe » : la suite garde ses positions d'origine.
      final texte = 'Cœur de karité';
      final trouve = searchMatchRange(texte, 'karite')!;
      expect(texte.substring(trouve.$1, trouve.$2), 'karité');
    });
  });

  group('DateFormatter.dayHeading', () {
    final maintenant = DateTime(2026, 10, 21, 9);

    test('aujourd\'hui, hier, puis la date', () {
      expect(
        DateFormatter.dayHeading(DateTime(2026, 10, 21, 1), now: maintenant),
        'Aujourd\'hui – mercredi 21 octobre 2026',
      );
      expect(
        DateFormatter.dayHeading(DateTime(2026, 10, 20, 23), now: maintenant),
        'Hier – mardi 20 octobre 2026',
      );
      expect(
        DateFormatter.dayHeading(DateTime(2026, 10, 17), now: maintenant),
        'samedi 17 octobre 2026',
      );
    });

    test('le premier du mois s\'écrit « 1er »', () {
      expect(
        DateFormatter.formatDayMonthYear(DateTime(2026, 11)),
        '1er novembre 2026',
      );
      expect(
        DateFormatter.formatLongDate(DateTime(2026, 11)),
        'dimanche 1er novembre 2026',
      );
      expect(DateFormatter.formatDayMonth(DateTime(2026, 11, 2)), '2 novembre');
    });
  });
}
