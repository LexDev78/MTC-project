import 'dart:async';

import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/favorite.dart';

class InMemoryFavoriteDatasource {
  InMemoryFavoriteDatasource() {
    // A pre-favorited item for the demo client, so the tab isn't empty.
    _favorites.add(
      Favorite(
        id: IdGenerator.next(),
        userId: DemoIds.clientAwa,
        productId: 'product-001',
        createdAt: DateTime.now(),
      ),
    );
  }

  final List<Favorite> _favorites = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<Favorite>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<Favorite>.unmodifiable(_favorites));
  }

  void add(Favorite favorite) {
    _favorites.add(favorite);
    _changesController.add(null);
  }

  void remove({required String userId, required String productId}) {
    _favorites.removeWhere(
      (f) => f.userId == userId && f.productId == productId,
    );
    _changesController.add(null);
  }
}
