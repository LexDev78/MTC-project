import '../entities/product_review.dart';
import '../entities/review.dart';

abstract interface class ReviewRepository {
  Stream<List<Review>> watchForSupplier(String supplierId);

  Future<void> submitReview({
    required String orderId,
    required String supplierGroupId,
    required String clientId,
    required String supplierId,
    required int stars,
    required String comment,
    List<String> imagePaths,
    String? videoPath,
  });

  /// Avis des acheteurs d'un produit, pour sa fiche publique.
  Future<List<ProductReview>> fetchProductReviews({
    required String productId,
    int limit,
    int offset,
  });

  Future<ProductReviewSummary> fetchProductReviewSummary(String productId);

  /// Commente un avis. L'auteur est déterminé côté serveur, pas ici.
  Future<void> addComment({
    required String reviewId,
    required String body,
    List<String> imagePaths,
    String? videoPath,
  });

  Future<void> deleteComment(String commentId);

  Future<bool> canReview({
    required String orderId,
    required String supplierGroupId,
  });

  /// Records the supplier's public reply to [reviewId] — throws
  /// `ValidationException` if [supplierId] isn't the supplier that review
  /// was left for (a supplier can't reply to another's review).
  Future<void> reply({
    required String reviewId,
    required String supplierId,
    required String reply,
  });
}
