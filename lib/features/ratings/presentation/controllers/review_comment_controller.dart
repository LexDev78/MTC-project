import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/review_providers.dart';

/// Ajout et retrait des commentaires sous un avis.
///
/// Ne décide de rien sur l'auteur : un trigger pose `author_id`, le nom
/// affiché et le fait que ce soit le vendeur qui parle
/// (`stamp_review_comment_author`, `0061`). Le contrôleur ne sait donc même
/// pas qui écrit — c'est voulu, il n'y a qu'une vérité et elle est en base.
class ReviewCommentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [productId] n'est pas utilisé par l'écriture : il sert à invalider la
  /// bonne fiche après coup. Sans lui, le commentaire partirait sans que la
  /// liste bouge, et on le réécrirait en croyant l'avoir perdu.
  Future<bool> add({
    required String reviewId,
    required String productId,
    required String body,
    List<String> imagePaths = const [],
    String? videoPath,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(reviewRepositoryProvider)
          .addComment(
            reviewId: reviewId,
            body: body,
            imagePaths: imagePaths,
            videoPath: videoPath,
          ),
    );
    if (state.hasError) return false;
    ref.invalidate(productReviewsProvider(productId));
    return true;
  }

  Future<bool> remove({
    required String commentId,
    required String productId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(reviewRepositoryProvider).deleteComment(commentId),
    );
    if (state.hasError) return false;
    ref.invalidate(productReviewsProvider(productId));
    return true;
  }
}

final reviewCommentControllerProvider =
    AsyncNotifierProvider<ReviewCommentController, void>(
      ReviewCommentController.new,
    );
