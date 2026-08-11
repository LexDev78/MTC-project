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
  });

  Future<bool> canReview({
    required String orderId,
    required String supplierGroupId,
  });
}
