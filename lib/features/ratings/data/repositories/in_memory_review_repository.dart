import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';
import '../datasources/in_memory_review_datasource.dart';

class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository(this._datasource);

  final InMemoryReviewDatasource _datasource;

  @override
  Stream<List<Review>> watchForSupplier(String supplierId) {
    return _datasource.watchAll().map(
      (reviews) =>
          reviews.where((r) => r.supplierId == supplierId).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<void> submitReview({
    required String orderId,
    required String supplierGroupId,
    required String clientId,
    required String supplierId,
    required int stars,
    required String comment,
  }) async {
    _datasource.add(
      Review(
        id: IdGenerator.next(),
        orderId: orderId,
        supplierGroupId: supplierGroupId,
        clientId: clientId,
        supplierId: supplierId,
        stars: stars,
        comment: comment,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<bool> canReview({
    required String orderId,
    required String supplierGroupId,
  }) async {
    return !_datasource.hasReview(orderId, supplierGroupId);
  }
}
