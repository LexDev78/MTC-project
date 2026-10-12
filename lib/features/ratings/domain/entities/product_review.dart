import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_review.freezed.dart';
part 'product_review.g.dart';

/// Un avis tel qu'un visiteur le lit sur une fiche produit.
///
/// Distinct de [Review] (`review.dart`), qui est la ligne telle que le
/// fournisseur la gère : ici il n'y a ni identifiant de commande, ni de
/// client, ni de groupe — rien qui ne doive pas se retrouver sur une page
/// publique. Seul le prénom figé à l'écriture reste, posé par la base et non
/// par l'auteur (`stamp_review_author`, `0061`).
///
/// Un avis porte sur une **commande chez un vendeur**, pas sur un article :
/// il apparaît sur la fiche parce que la commande contenait ce produit. La
/// section l'énonce ainsi plutôt que de faire croire à une note par article.
@freezed
class ProductReview with _$ProductReview {
  const factory ProductReview({
    required String id,
    required int stars,
    required String comment,
    required DateTime createdAt,
    required String authorName,

    /// Photos de l'acheteur — ce qui fait la valeur d'un avis, par
    /// différence avec les photos du vendeur.
    @Default([]) List<String> imagePaths,
    String? videoPath,
    String? supplierReply,
    DateTime? supplierRepliedAt,
    @Default([]) List<ReviewComment> comments,
  }) = _ProductReview;

  factory ProductReview.fromJson(Map<String, dynamic> json) =>
      _$ProductReviewFromJson(json);
}

/// Un commentaire sous un avis : une question d'un autre client, une
/// précision, ou la réponse publique du vendeur.
@freezed
class ReviewComment with _$ReviewComment {
  const factory ReviewComment({
    required String id,
    required String body,
    required DateTime createdAt,
    required String authorName,

    /// Calculé à l'écriture, pas déclaré par l'auteur : un commentaire du
    /// vendeur ne se lit pas comme celui d'un acheteur.
    @Default(false) bool authorIsSupplier,
    @Default([]) List<String> imagePaths,
    String? videoPath,
  }) = _ReviewComment;

  factory ReviewComment.fromJson(Map<String, dynamic> json) =>
      _$ReviewCommentFromJson(json);
}

/// L'en-tête de la section : combien d'avis, et quelle moyenne.
///
/// Ne se confond pas avec `Product.ratingAverage`, qui recopie la note du
/// **fournisseur** sur chacun de ses produits pour que le tri du catalogue
/// n'ait pas à faire de jointure. Ici c'est la note des acheteurs de ce
/// produit-là, et les deux peuvent légitimement différer.
@freezed
class ProductReviewSummary with _$ProductReviewSummary {
  const factory ProductReviewSummary({
    required int reviewCount,
    required double ratingAverage,
  }) = _ProductReviewSummary;
}
