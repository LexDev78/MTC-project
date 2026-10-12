import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_review_datasource.dart';
import '../../data/repositories/supabase_review_repository.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

final reviewDatasourceProvider = Provider<SupabaseReviewDatasource>((ref) {
  return SupabaseReviewDatasource(ref.watch(supabaseClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.watch(reviewDatasourceProvider));
});

final supplierReviewsProvider = StreamProvider.family<List<Review>, String>((
  ref,
  supplierId,
) {
  return ref.watch(reviewRepositoryProvider).watchForSupplier(supplierId);
});

typedef ReviewKey = ({String orderId, String groupId});

final canReviewProvider = FutureProvider.family<bool, ReviewKey>((ref, key) {
  return ref
      .watch(reviewRepositoryProvider)
      .canReview(orderId: key.orderId, supplierGroupId: key.groupId);
});

/// Avis des acheteurs d'un produit, pour sa fiche.
///
/// Requête ponctuelle, pas de flux : un avis arrive après une livraison,
/// donc des jours après la visite d'une fiche. Ce qui bouge en direct, ce
/// sont les commentaires qu'on y ajoute — et c'est le contrôleur qui
/// invalide alors cette lecture.
final productReviewsProvider =
    FutureProvider.family<List<ProductReview>, String>((ref, productId) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchProductReviews(productId: productId);
    });

final productReviewSummaryProvider =
    FutureProvider.family<ProductReviewSummary, String>((ref, productId) {
      return ref
          .watch(reviewRepositoryProvider)
          .fetchProductReviewSummary(productId);
    });
