import 'dart:async';

import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../domain/entities/review.dart';

class InMemoryReviewDatasource {
  InMemoryReviewDatasource() {
    _reviews.addAll(_seed());
  }

  final List<Review> _reviews = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<Review>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<Review>.unmodifiable(_reviews));
  }

  void add(Review review) {
    _reviews.add(review);
    _changesController.add(null);
  }

  bool hasReview(String orderId, String supplierGroupId) {
    return _reviews.any(
      (r) => r.orderId == orderId && r.supplierGroupId == supplierGroupId,
    );
  }

  Review? getById(String reviewId) {
    for (final review in _reviews) {
      if (review.id == reviewId) return review;
    }
    return null;
  }

  void update(Review review) {
    final index = _reviews.indexWhere((r) => r.id == review.id);
    if (index == -1) return;
    _reviews[index] = review;
    _changesController.add(null);
  }

  List<Review> _seed() {
    final now = DateTime.now();
    return [
      Review(
        id: 'seed-review-1',
        orderId: 'seed-order-1',
        supplierGroupId: 'seed-group-1',
        clientId: DemoIds.clientMoussa,
        supplierId: DemoIds.supplierBogolanBamako,
        stars: 5,
        comment: 'Très beau tissu, livraison rapide.',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Review(
        id: 'seed-review-2',
        orderId: 'seed-order-2',
        supplierGroupId: 'seed-group-2',
        clientId: DemoIds.clientAwa,
        supplierId: DemoIds.supplierAlimentationSegou,
        stars: 5,
        comment: 'Riz de très bonne qualité, je recommande.',
        createdAt: now.subtract(const Duration(days: 20)),
      ),
    ];
  }
}
