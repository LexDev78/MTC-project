import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../data/datasources/supabase_favorite_datasource.dart';
import '../../data/repositories/supabase_favorite_repository.dart';
import '../../domain/repositories/favorite_repository.dart';

final favoriteDatasourceProvider = Provider<SupabaseFavoriteDatasource>((ref) {
  return SupabaseFavoriteDatasource(ref.watch(supabaseClientProvider));
});

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return SupabaseFavoriteRepository(ref.watch(favoriteDatasourceProvider));
});

/// The current user's favorited product IDs. Empty when signed out.
final favoriteProductIdsProvider = StreamProvider<Set<String>>((ref) {
  // `.select`: see the same note in cart_providers.dart — avoids
  // rebuilding (and losing the in-flight subscription) on a re-emitted
  // but id-equal AppUser.
  final userId = ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id));
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

/// The quantity picked for a favorited product, used both by its row's own
/// "Acheter"/"Ajouter au panier" buttons and by the favorites screen's bulk
/// selection actions, so a bulk add honors each item's chosen quantity
/// instead of defaulting to 1. Isolated per product and auto-disposed once
/// its row leaves the screen.
final favoriteQuantityProvider = StateProvider.autoDispose.family<int, String>(
  (ref, productId) => 1,
);
