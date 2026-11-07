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

/// Les produits mis de côté, pour la grille des favoris.
///
/// En une requête (`fetchByIds`) plutôt qu'une par favori : sur un réseau
/// lent, dix favoris faisaient dix allers-retours. Un produit devenu
/// invisible (retiré, boutique suspendue) tombe de lui-même, au lieu de
/// faire échouer toute la liste comme le faisait sa lecture une à une.
///
/// Ces produits n'embarquent pas leurs variantes (voir `fetchByIds`) : un
/// ajout au panier depuis les favoris relit le produit complet d'abord.
final favoriteProductsProvider = FutureProvider<List<Product>>((ref) async {
  final ids = await ref.watch(favoriteProductIdsProvider.future);
  if (ids.isEmpty) return const [];
  return ref.watch(productRepositoryProvider).fetchByIds(ids.toList());
});
