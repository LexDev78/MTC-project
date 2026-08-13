import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_product_datasource.dart';
import '../../data/repositories/supabase_product_repository.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/repositories/product_repository.dart';

final productDatasourceProvider = Provider<SupabaseProductDatasource>((ref) {
  return SupabaseProductDatasource(ref.watch(supabaseClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return SupabaseProductRepository(ref.watch(productDatasourceProvider));
});

/// Search text, isolated per [SupplierType] tab so typing in one catalog
/// tab never affects the other.
final catalogQueryProvider = StateProvider.family<String, SupplierType>(
  (ref, type) => '',
);

/// Selected category filter, isolated per [SupplierType] tab.
final catalogCategoryProvider =
    StateProvider.family<ProductCategory?, SupplierType>((ref, type) => null);

/// Sort applied on top of the repository query, isolated per tab.
final catalogSortProvider = StateProvider.family<ProductSortOption, SupplierType>(
  (ref, type) => ProductSortOption.relevance,
);

/// Price-range filter (inclusive, in FCFA), isolated per tab. `null` means
/// "no bound on this side".
final catalogMinPriceProvider = StateProvider.family<int?, SupplierType>(
  (ref, type) => null,
);
final catalogMaxPriceProvider = StateProvider.family<int?, SupplierType>(
  (ref, type) => null,
);

/// Selected size/color filters, isolated per tab. Empty set means "no
/// restriction on this axis" — a product matches if it has *any* of the
/// selected values (OR within an axis, AND across axes).
final catalogSelectedSizesProvider =
    StateProvider.family<Set<String>, SupplierType>((ref, type) => const {});
final catalogSelectedColorsProvider =
    StateProvider.family<Set<String>, SupplierType>((ref, type) => const {});

/// Selected region filter (provenance: Chine/Europe/Afrique/Mali/Autre),
/// isolated per tab — same OR-within-axis semantics as sizes/colors, and
/// unlike them it's a fixed enum so the filter sheet always shows every
/// value rather than only the ones present in the current result set.
final catalogSelectedRegionsProvider =
    StateProvider.family<Set<ProductRegion>, SupplierType>(
      (ref, type) => const {},
    );

/// Every distinct size/color value available across this tab's products
/// (ignoring the current filter selections), used to populate the filter
/// sheet's chip options — empty for tabs where no product has that axis
/// (e.g. matériaux/alimentation), so the sheet just hides that section.
final catalogAvailableSizesProvider =
    StreamProvider.family<List<String>, SupplierType>((ref, type) {
      final repository = ref.watch(productRepositoryProvider);
      return repository.watchProducts(supplierType: type).map((products) {
        final values = <String>{};
        for (final p in products) {
          values.addAll(p.sizes);
        }
        final sorted = values.toList()..sort();
        return sorted;
      });
    });
final catalogAvailableColorsProvider =
    StreamProvider.family<List<String>, SupplierType>((ref, type) {
      final repository = ref.watch(productRepositoryProvider);
      return repository.watchProducts(supplierType: type).map((products) {
        final values = <String>{};
        for (final p in products) {
          values.addAll(p.colors);
        }
        final sorted = values.toList()..sort();
        return sorted;
      });
    });

/// Whether any filter (price/size/color/sort) beyond category/search is
/// currently active — drives the badge dot on the filter icon.
final catalogHasActiveFilterProvider = Provider.family<bool, SupplierType>((
  ref,
  type,
) {
  return ref.watch(catalogMinPriceProvider(type)) != null ||
      ref.watch(catalogMaxPriceProvider(type)) != null ||
      ref.watch(catalogSelectedSizesProvider(type)).isNotEmpty ||
      ref.watch(catalogSelectedColorsProvider(type)).isNotEmpty ||
      ref.watch(catalogSelectedRegionsProvider(type)).isNotEmpty ||
      ref.watch(catalogSortProvider(type)) != ProductSortOption.relevance;
});

/// The cheapest/priciest product currently available for this tab
/// (ignoring the price filter itself, so the slider's bounds stay stable
/// while the user drags it), used to size the filter sheet's price slider.
final catalogPriceBoundsProvider =
    StreamProvider.family<(int min, int max), SupplierType>((ref, type) {
      final repository = ref.watch(productRepositoryProvider);
      return repository.watchProducts(supplierType: type).map((products) {
        if (products.isEmpty) return (0, 0);
        var min = products.first.priceFcfa;
        var max = products.first.priceFcfa;
        for (final p in products) {
          if (p.priceFcfa < min) min = p.priceFcfa;
          if (p.priceFcfa > max) max = p.priceFcfa;
        }
        return (min, max);
      });
    });

final productListProvider = StreamProvider.family<List<Product>, SupplierType>((
  ref,
  type,
) {
  final repository = ref.watch(productRepositoryProvider);
  final query = ref.watch(catalogQueryProvider(type));
  final category = ref.watch(catalogCategoryProvider(type));
  final minPrice = ref.watch(catalogMinPriceProvider(type));
  final maxPrice = ref.watch(catalogMaxPriceProvider(type));
  final sort = ref.watch(catalogSortProvider(type));
  final selectedSizes = ref.watch(catalogSelectedSizesProvider(type));
  final selectedColors = ref.watch(catalogSelectedColorsProvider(type));
  final selectedRegions = ref.watch(catalogSelectedRegionsProvider(type));

  return repository
      .watchProducts(
        supplierType: type,
        category: category,
        query: query.isEmpty ? null : query,
      )
      .map((products) {
        var filtered = products.where((p) {
          if (minPrice != null && p.priceFcfa < minPrice) return false;
          if (maxPrice != null && p.priceFcfa > maxPrice) return false;
          if (selectedSizes.isNotEmpty &&
              !p.sizes.any(selectedSizes.contains)) {
            return false;
          }
          if (selectedColors.isNotEmpty &&
              !p.colors.any(selectedColors.contains)) {
            return false;
          }
          if (selectedRegions.isNotEmpty &&
              !selectedRegions.contains(p.region)) {
            return false;
          }
          return true;
        }).toList();
        switch (sort) {
          case ProductSortOption.relevance:
            break;
          case ProductSortOption.priceAsc:
            filtered.sort((a, b) => a.priceFcfa.compareTo(b.priceFcfa));
          case ProductSortOption.priceDesc:
            filtered.sort((a, b) => b.priceFcfa.compareTo(a.priceFcfa));
          case ProductSortOption.ratingDesc:
            filtered.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
          case ProductSortOption.newest:
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }
        return filtered;
      });
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

/// Global search (across both supplier types), used by `search_screen.dart`.
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

final globalSearchResultsProvider = StreamProvider<List<Product>>((ref) {
  final query = ref.watch(globalSearchQueryProvider).trim();
  if (query.isEmpty) return Stream.value(const []);
  return ref.watch(productRepositoryProvider).watchProducts(query: query);
});
