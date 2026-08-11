import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../data/datasources/in_memory_favorite_datasource.dart';
import '../../data/repositories/in_memory_favorite_repository.dart';
import '../../domain/repositories/favorite_repository.dart';

final favoriteDatasourceProvider = Provider<InMemoryFavoriteDatasource>((ref) {
  return InMemoryFavoriteDatasource();
});

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return InMemoryFavoriteRepository(ref.watch(favoriteDatasourceProvider));
});

/// The current user's favorited product IDs. Empty when signed out.
final favoriteProductIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const <String>{});
  return ref
      .watch(favoriteRepositoryProvider)
      .watchForUser(userId)
      .map((favorites) => favorites.map((f) => f.productId).toSet());
});

final isFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  final ids =
      ref.watch(favoriteProductIdsProvider).valueOrNull ?? const <String>{};
  return ids.contains(productId);
});

/// Full [Product] objects for every favorited ID, for the favorites screen.
final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final ids = await ref.watch(favoriteProductIdsProvider.future);
  final repository = ref.watch(productRepositoryProvider);
  return Future.wait(ids.map(repository.getById));
});
