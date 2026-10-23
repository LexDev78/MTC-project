import '../entities/product_review.dart';
import '../entities/review.dart';
import '../entities/review_sort.dart';

abstract interface class ReviewRepository {
  Stream<List<Review>> watchForSupplier(String supplierId);

  /// Dépose l'avis, et avec lui la moyenne du fournisseur, sa recopie sur
  /// ses produits et la notification — toutes faites côté serveur
  /// (`submit_review`, `0063`). Ni `clientId` ni `supplierId` ne sont
  /// transmis : le serveur les déduit de la commande et de l'appelant.
  Future<void> submitReview({
    required String orderId,
    required String supplierGroupId,
    required int stars,
    required String comment,
    List<String> imagePaths,
    String? videoPath,

    /// Facultatif (`0119`) : une ligne qui résume l'avis, 100 caractères au
    /// plus. Vide ou blanc, il n'y en a pas.
    String? title,
  });

  /// Avis des acheteurs d'un produit, pour sa fiche publique, une page à la
  /// fois et dans l'ordre [sort].
  Future<List<ProductReview>> fetchProductReviews({
    required String productId,
    int limit,
    int offset,
    ReviewSort sort,
  });

  Future<ProductReviewSummary> fetchProductReviewSummary(String productId);

  /// Le nombre d'avis par note (1 à 5) ; une note sans avis est absente.
  Future<Map<int, int>> fetchProductRatingDistribution(String productId);

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
