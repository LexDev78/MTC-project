import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/product_selection.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_buy_sheet.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_info_sheets.dart';
import 'package:mtc_app/features/comments/presentation/providers/comment_providers.dart';
import 'package:mtc_app/features/favorites/presentation/providers/favorite_providers.dart';
import 'package:mtc_app/features/ratings/domain/entities/product_review.dart';
import 'package:mtc_app/features/ratings/presentation/providers/review_providers.dart';
import 'package:mtc_app/features/ratings/presentation/screens/product_reviews_screen.dart';
import 'package:mtc_app/features/recommendations/domain/repositories/recommendation_repository.dart';
import 'package:mtc_app/features/recommendations/presentation/providers/recommendation_providers.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

/// Les deux traces d'une visite de fiche, sans base.
class _Produits implements ProductRepository {
  @override
  Future<void> incrementViewCount(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Recommandations implements RecommendationRepository {
  @override
  Future<void> logProductView(String productId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _fiche(Product p) {
  final similaires = catalogueDemo().where((x) => x.id != p.id).toList();
  return [
    productDetailProvider(p.id).overrideWith((ref) async => p),
    productRepositoryProvider.overrideWithValue(_Produits()),
    recommendationRepositoryProvider.overrideWithValue(_Recommandations()),
    favoriteProductIdsProvider.overrideWith((ref) => Stream.value(const {})),
    productReviewSummaryProvider(p.id).overrideWith(
      (ref) async =>
          const ProductReviewSummary(reviewCount: 3, ratingAverage: 4),
    ),
    productRatingDistributionProvider(
      p.id,
    ).overrideWith((ref) async => {5: 1, 4: 1, 3: 1}),
    productCommentsProvider(
      p.id,
    ).overrideWith((ref) => Stream.value(commentairesDemo())),
    similarProductsProvider(p).overrideWith((ref) => Stream.value(similaires)),
    productReviewsPageProvider.overrideWith(
      (ref, cle) async => cle.page == 0 ? avisDemo() : const [],
    ),
  ];
}

/// Le contenu d'une feuille, posé comme `showShopSheet` le pose : sur le
/// fond de la toile, sous un `Material` (sans lui, les textes n'ont pas de
/// style par défaut).
Widget _feuille(Widget contenu) => Scaffold(body: SafeArea(child: contenu));

/// La feuille d'achat sur une variante donnée, comme la fiche l'aurait
/// posée.
List<Override> _achat(String variante, Map<String, String> choix) {
  final p = bogolanAVariantes();
  return [
    ..._fiche(p),
    productVariantIdProvider(p.id).overrideWith((ref) => variante),
    productPicksProvider(p.id).overrideWith((ref) => choix),
  ];
}

void main() {
  capturerEcran(
    'fiche_produit',
    () => const ProductDetailScreen(productId: 'bogolan'),
    overrides: () => _fiche(bogolanAVariantes()),
  );
  capturerEcran(
    'fiche_produit_page',
    () => const ProductDetailScreen(productId: 'bogolan'),
    overrides: () => _fiche(bogolanAVariantes()),
    hauteur: 1600,
  );
  capturerEcran(
    'fiche_rupture',
    () => const ProductDetailScreen(productId: 'bogolan'),
    overrides: () =>
        _fiche(bogolanAVariantes().copyWith(stockQuantity: 0)),
  );
  capturerEcran(
    'fiche_achat',
    () => ProductBuySheet(product: bogolanAVariantes()),
    overrides: () => _achat('v-indigo-2', {
      'c-couleur': 'o-indigo',
      'c-longueur': 'o-2m',
    }),
    hauteur: 1250,
  );
  capturerEcran(
    'fiche_achat_a_trancher',
    () => ProductBuySheet(product: bogolanAVariantes()),
    overrides: () => _achat('v-ocre', {'c-couleur': 'o-ocre'}),
    hauteur: 1250,
  );
  capturerEcran(
    'ajoute_au_panier',
    () => const AddedToCartSheet(),
  );
  capturerEcran(
    'details_produit',
    () => _feuille(ProductDetailsSheet(product: bogolanAVariantes())),
  );
  capturerEcran(
    'modes_livraison',
    () => _feuille(DeliveryMethodsSheet(product: bogolanAVariantes())),
  );
  capturerEcran(
    'avis',
    () => const ProductReviewsScreen(productId: 'bogolan'),
    overrides: () => _fiche(bogolanAVariantes()),
    hauteur: 1400,
  );
  capturerEcran(
    'avis_tri',
    () => const ProductReviewsScreen(productId: 'bogolan'),
    overrides: () => _fiche(bogolanAVariantes()),
    geste: (tester) async {
      // Un premier `pump` lance l'animation de la feuille, le second la
      // termine : sans lui, le choix est encore sous l'écran.
      await tester.tap(find.text('Plus récents'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Moins bien notés'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
  capturerEcran(
    'fiche_feuille_achat',
    () => const ProductDetailScreen(productId: 'bogolan'),
    overrides: () => _fiche(bogolanAVariantes()),
    geste: (tester) async {
      await tester.tap(find.text('Acheter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    },
  );
}
