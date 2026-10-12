import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../providers/review_providers.dart';

class ReviewController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> submit({
    required String orderId,
    required String supplierGroupId,
    required String supplierId,
    required int stars,
    required String comment,
    List<String> imagePaths = const [],
    String? videoPath,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(reviewRepositoryProvider)
          .submitReview(
            orderId: orderId,
            supplierGroupId: supplierGroupId,
            stars: stars,
            comment: comment,
            imagePaths: imagePaths,
            videoPath: videoPath,
          ),
    );
    if (state.hasError) return false;

    // La moyenne du fournisseur, sa recopie sur ses produits et la
    // notification sont écrites par `submit_review` (`0063`). L'app ne les
    // produit plus — elle doit en revanche oublier ce qu'elle a en cache,
    // puisque ces lignes ont changé sans passer par elle.
    ref.invalidate(supplierDetailProvider(supplierId));
    ref.invalidate(productDetailProvider);
    ref.invalidate(productReviewsProvider);
    ref.invalidate(productReviewSummaryProvider);
    return true;
  }

  Future<bool> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(reviewRepositoryProvider)
          .reply(reviewId: reviewId, supplierId: supplierId, reply: reply),
    );

    return !state.hasError;
  }
}

final reviewControllerProvider = AsyncNotifierProvider<ReviewController, void>(
  ReviewController.new,
);
