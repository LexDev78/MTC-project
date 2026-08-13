import 'dart:async';

import 'package:mtc_app/core/mock_data/demo_ids.dart';

import '../../domain/entities/product_comment.dart';

class InMemoryProductCommentDatasource {
  InMemoryProductCommentDatasource() {
    _comments.addAll(_seed());
  }

  final List<ProductComment> _comments = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<ProductComment>> watchForProduct(String productId) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) {
      return List<ProductComment>.unmodifiable(
        _comments.where((c) => c.productId == productId),
      );
    });
  }

  Stream<List<ProductComment>> watchForSupplier(String supplierId) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) {
      return List<ProductComment>.unmodifiable(
        _comments.where((c) => c.supplierId == supplierId),
      );
    });
  }

  void addComment(ProductComment comment) {
    _comments.add(comment);
    _changesController.add(null);
  }

  void toggleLike(String commentId, String userId) {
    final index = _comments.indexWhere((c) => c.id == commentId);
    if (index == -1) return;

    final comment = _comments[index];
    final likedByUserIds = {...comment.likedByUserIds};
    if (!likedByUserIds.remove(userId)) likedByUserIds.add(userId);

    _comments[index] = comment.copyWith(likedByUserIds: likedByUserIds);
    _changesController.add(null);
  }

  /// Seeded on the very first product ("Tissu Bogolan traditionnel", id
  /// `product-001` — stable because `InMemoryProductDatasource` seeds
  /// products in a fixed order) so the feature has something to show
  /// without needing a fresh comment first.
  List<ProductComment> _seed() {
    final now = DateTime.now();
    return [
      ProductComment(
        id: 'comment-001',
        productId: 'product-001',
        supplierId: DemoIds.supplierBogolanBamako,
        authorId: DemoIds.clientMoussa,
        authorName: 'Moussa Diarra',
        createdAt: now.subtract(const Duration(days: 2)),
        text:
            "Le tissu est-il aussi solide qu'il en a l'air ? Je cherche quelque chose de durable pour un boubou de tous les jours.",
      ),
      ProductComment(
        id: 'comment-002',
        productId: 'product-001',
        supplierId: DemoIds.supplierBogolanBamako,
        authorId: DemoIds.supplierBogolanBamako,
        authorName: 'Bogolan Bamako',
        createdAt: now.subtract(const Duration(days: 1, hours: 20)),
        text:
            "Oui, c'est un coton épais tissé main, teint deux fois pour bien fixer les motifs. Très résistant à l'usage quotidien.",
        isSupplier: true,
        parentId: 'comment-001',
      ),
      ProductComment(
        id: 'comment-003',
        productId: 'product-001',
        supplierId: DemoIds.supplierBogolanBamako,
        authorId: DemoIds.clientAwa,
        authorName: 'Awa Traoré',
        createdAt: now.subtract(const Duration(hours: 5)),
        text: 'Magnifiques couleurs, exactement comme sur les photos !',
        likedByUserIds: {DemoIds.clientMoussa},
      ),
    ];
  }
}
