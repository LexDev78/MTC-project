import 'package:mtc_app/core/error/exceptions.dart';

import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/supabase_review_datasource.dart';

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._datasource);

  final SupabaseReviewDatasource _datasource;

  @override
  Stream<List<Review>> watchForSupplier(String supplierId) {
    return _datasource
        .watchForSupplier(supplierId)
        .map((rows) => rows.map(Review.fromJson).toList());
  }

  @override
  Future<void> submitReview({
    required String orderId,
    required String supplierGroupId,
    required String clientId,
    required String supplierId,
    required int stars,
    required String comment,
  }) {
    return _datasource.submitReview({
      'order_id': orderId,
      'supplier_group_id': supplierGroupId,
      'client_id': clientId,
      'supplier_id': supplierId,
      'stars': stars,
      'comment': comment,
    });
  }

  @override
  Future<bool> canReview({
    required String orderId,
    required String supplierGroupId,
  }) async {
    final hasReview = await _datasource.hasReview(
      orderId: orderId,
      supplierGroupId: supplierGroupId,
    );
    return !hasReview;
  }

  @override
  Future<void> reply({
    required String reviewId,
    required String supplierId,
    required String reply,
  }) async {
    final row = await _datasource.getById(reviewId);
    if (row == null) {
      throw const NotFoundException('Avis introuvable');
    }
    if (row['supplier_id'] != supplierId) {
      throw const ValidationException('Cet avis ne concerne pas votre boutique');
    }
    await _datasource.reply(reviewId: reviewId, reply: reply);
  }
}
