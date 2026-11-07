import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_product_datasource.dart';
import '../../data/repositories/supabase_product_repository.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/product_list_filters.dart';
import '../../domain/repositories/product_repository.dart';

final productDatasourceProvider = Provider<SupabaseProductDatasource>((ref) {
  return SupabaseProductDatasource(ref.watch(supabaseClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return SupabaseProductRepository(ref.watch(productDatasourceProvider));
});

/// Products similar to [product] — same category and supplier side,
/// excluding the product itself — shown as the product detail page's
/// "Voir aussi" section.
final similarProductsProvider = StreamProvider.family<List<Product>, Product>((
  ref,
  product,
) {
  final repository = ref.watch(productRepositoryProvider);
  return repository
      .watchProducts(
        supplierType: product.supplierType,
        category: product.category,
      )
      .map(
        (products) =>
            products.where((p) => p.id != product.id).take(10).toList(),
      );
});

final productDetailProvider = FutureProvider.family<Product, String>((ref, id) {
  return ref.watch(productRepositoryProvider).getById(id);
});

/// All visible products from one specific supplier — used by the supplier
/// profile screen.
final supplierProductsProvider = StreamProvider.family<List<Product>, String>((
  ref,
  supplierId,
) {
  return ref
      .watch(productRepositoryProvider)
      .watchProducts(supplierId: supplierId);
});

/// Les filtres et le tri de la liste d'une catégorie (`CategoryProductsScreen`),
/// gardés par catégorie : en revenant sur « Électronique », on retrouve ses
/// propres réglages.
final categoryFiltersProvider =
    StateProvider.family<ProductListFilters, ProductCategory>(
      (ref, category) => const ProductListFilters(),
    );

/// Tout ce que [ProductCategory] propose, des deux types de fournisseurs, avant
/// filtres : la matière des facettes et des bornes de prix de la feuille, qui
/// ne doivent pas rétrécir à mesure qu'on filtre.
final categoryAllProductsProvider =
    StreamProvider.family<List<Product>, ProductCategory>((ref, category) {
      return ref
          .watch(productRepositoryProvider)
          .watchProducts(category: category);
    });

/// La liste de la catégorie, filtres et tri appliqués.
final categoryProductListProvider =
    Provider.family<AsyncValue<List<Product>>, ProductCategory>((
      ref,
      category,
    ) {
      final filtres = ref.watch(categoryFiltersProvider(category));
      return ref
          .watch(categoryAllProductsProvider(category))
          .whenData(filtres.apply);
    });

/// Le texte cherché, une fois la frappe posée (`SearchScreen`). Oublié en
/// quittant l'écran, comme ses filtres : une recherche rouverte part vide.
final globalSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Les filtres et le tri des résultats de recherche.
final searchFiltersProvider = StateProvider.autoDispose<ProductListFilters>(
  (ref) => const ProductListFilters(),
);

/// Tous les produits qui répondent au texte cherché, des deux types de
/// fournisseurs, avant filtres.
final globalSearchResultsProvider = StreamProvider.autoDispose<List<Product>>((
  ref,
) {
  final query = ref.watch(globalSearchQueryProvider).trim();
  if (query.isEmpty) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).watchProducts(query: query);
});

/// Les résultats de recherche, filtres et tri appliqués.
final searchResultsProvider = Provider.autoDispose<AsyncValue<List<Product>>>((
  ref,
) {
  final filtres = ref.watch(searchFiltersProvider);
  return ref.watch(globalSearchResultsProvider).whenData(filtres.apply);
});

/// Per-product favorite/order counts for the supplier dashboard's product
/// cards — fetched once per screen visit (`FutureProvider`, not a stream)
/// like the notification center's "next visit" refresh, not a live
/// subscription: view/like/order counts are analytics-ish, not
/// action-critical, so they don't need second-by-second updates.
/// `autoDispose` so "once per screen visit" is actually true — a plain
/// `FutureProvider` stays cached (and increasingly stale) for the whole app
/// session once first created, since nothing ever explicitly invalidates it.
final productStatsProvider =
    FutureProvider.autoDispose.family<Map<String, ProductStats>, String>((
      ref,
      supplierId,
    ) {
      return ref.watch(productRepositoryProvider).fetchProductStats(supplierId);
    });
