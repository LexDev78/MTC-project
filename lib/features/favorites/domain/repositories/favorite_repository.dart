import '../entities/favorite.dart';

abstract interface class FavoriteRepository {
  Stream<List<Favorite>> watchForUser(String userId);

  Future<void> addFavorite({required String userId, required String productId});

  Future<void> removeFavorite({
    required String userId,
    required String productId,
  });
}
