import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

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
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(reviewRepositoryProvider)
          .submitReview(
            orderId: orderId,
            supplierGroupId: supplierGroupId,
            clientId: userId,
            supplierId: supplierId,
            stars: stars,
            comment: comment,
            imagePaths: imagePaths,
            videoPath: videoPath,
          );

      // Fold the new rating into the supplier, then propagate it to every
      // one of their products (Product.ratingAverage is a denormalized
      // copy so catalog sorting never needs a supplier join).
      final updated = await ref
          .read(supplierRepositoryProvider)
          .recordReview(supplierId: supplierId, stars: stars);
      await ref
          .read(productRepositoryProvider)
          .updateSupplierRating(
            supplierId: supplierId,
            ratingAverage: updated.average,
            ratingCount: updated.count,
          );
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: supplierId,
            type: NotificationType.newReview,
            title: 'Nouvel avis',
            body: '$stars★ — $comment',
          );
    });

    return !state.hasError;
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
