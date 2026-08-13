import '../../domain/entities/favorite.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../datasources/supabase_favorite_datasource.dart';

class SupabaseFavoriteRepository implements FavoriteRepository {
  SupabaseFavoriteRepository(this._datasource);

  final SupabaseFavoriteDatasource _datasource;

  @override
  Stream<List<Favorite>> watchForUser(String userId) {
    return _datasource
        .watchForUser(userId)
        .map((rows) => rows.map(Favorite.fromJson).toList());
  }

  @override
  Future<void> addFavorite({required String userId, required String productId}) {
    return _datasource.add(userId: userId, productId: productId);
  }

  @override
  Future<void> removeFavorite({required String userId, required String productId}) {
    return _datasource.remove(userId: userId, productId: productId);
  }
}
