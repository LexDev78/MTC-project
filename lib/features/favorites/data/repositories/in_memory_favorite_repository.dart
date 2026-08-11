import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/in_memory_favorite_datasource.dart';

class InMemoryFavoriteRepository implements FavoriteRepository {
  InMemoryFavoriteRepository(this._datasource);

  final InMemoryFavoriteDatasource _datasource;

  @override
  Stream<List<Favorite>> watchForUser(String userId) {
    return _datasource.watchAll().map(
      (favs) => favs.where((f) => f.userId == userId).toList(),
    );
  }

  @override
  Future<void> addFavorite({
    required String userId,
    required String productId,
  }) async {
    _datasource.add(
      Favorite(
        id: IdGenerator.next(),
        userId: userId,
        productId: productId,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    _datasource.remove(userId: userId, productId: productId);
  }
}
