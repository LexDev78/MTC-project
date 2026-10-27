import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_review_datasource.dart';
import '../../data/repositories/supabase_review_repository.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_sort.dart';
import '../../domain/repositories/review_repository.dart';

final reviewDatasourceProvider = Provider<SupabaseReviewDatasource>((ref) {
  return SupabaseReviewDatasource(ref.watch(supabaseClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.watch(reviewDatasourceProvider));
});

/// Les avis de la boutique **que l'on gère** : lignes complètes, pour y
/// répondre. Le serveur ne les rend qu'à la boutique concernée, à l'auteur
/// et au staff (`0134`).
final supplierReviewsProvider = StreamProvider.family<List<Review>, String>((
  ref,
  supplierId,
) {
  return ref.watch(reviewRepositoryProvider).watchForSupplier(supplierId);
});

/// Les cinq derniers avis d'une boutique, pour sa vitrine publique : ce qui
/// s'affiche, et rien de la commande ni du client (`fetch_supplier_reviews`,
/// `0134`).
final publicSupplierReviewsProvider = FutureProvider.autoDispose
    .family<List<ProductReview>, String>((ref, supplierId) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchSupplierReviews(supplierId, limit: 5);
    });

typedef ReviewKey = ({String orderId, String groupId});

/// `autoDispose`, et relu après chaque avis envoyé (`ReviewController`) :
/// c'est lui qui fait passer la commande de « Laisser un avis » à « Avis
/// publié ». Gardé en cache, il laissait le bouton en place après l'envoi —
/// comme si l'avis n'avait pas été enregistré.
final canReviewProvider = FutureProvider.autoDispose.family<bool, ReviewKey>((
  ref,
  key,
) {
  return ref
      .watch(reviewRepositoryProvider)
      .canReview(orderId: key.orderId, supplierGroupId: key.groupId);
});

/// Le nombre d'avis par page de l'écran « Avis ».
const reviewsPageSize = 20;

typedef ReviewPageKey = ({String productId, ReviewSort sort, int page});

/// Une page d'avis d'un produit, dans l'ordre choisi.
///
/// Requête ponctuelle, pas de flux : un avis arrive après une livraison,
/// donc des jours après la visite d'une fiche. Ce qui bouge en direct, ce
/// sont les commentaires qu'on y ajoute — et ce sont les contrôleurs qui
/// invalident alors ces lectures.
///
/// Une page de moins de [reviewsPageSize] avis est la dernière.
final productReviewsPageProvider = FutureProvider.autoDispose
    .family<List<ProductReview>, ReviewPageKey>((ref, key) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchProductReviews(
            productId: key.productId,
            sort: key.sort,
            limit: reviewsPageSize,
            offset: key.page * reviewsPageSize,
          );
    });

/// La répartition des avis par note, pour le résumé en barres du kit.
final productRatingDistributionProvider =
    FutureProvider.autoDispose.family<Map<int, int>, String>((ref, productId) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchProductRatingDistribution(productId);
    });

final productReviewSummaryProvider =
    FutureProvider.family<ProductReviewSummary, String>((ref, productId) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchProductReviewSummary(productId);
    });
