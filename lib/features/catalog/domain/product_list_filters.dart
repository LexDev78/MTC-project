import 'package:collection/collection.dart';

import 'package:mtc_app/core/utils/search_text.dart';

import 'entities/product.dart';
import 'entities/product_category.dart';
import 'promotion_pricing.dart';

/// Les filtres et le tri d'une liste de produits du côté client — la
/// feuille « Filtrer / Trier » du kit, pour une catégorie comme pour une
/// recherche.
///
/// Le prix qui compte est celui qu'affiche la carte : remise d'une unité
/// comprise. Borner ou trier sur le prix de base rangerait une carte à
/// 12 000 F après une autre à 13 000 F, et une réglette « jusqu'à 12 000 F »
/// écarterait un article affiché à ce prix.
class ProductListFilters {
  const ProductListFilters({
    this.sort = ProductSortOption.relevance,
    this.minPriceFcfa,
    this.maxPriceFcfa,
    this.inStockOnly = false,
    this.categories = const {},
    this.supplierIds = const {},
  });

  final ProductSortOption sort;

  /// Bornes incluses ; `null` : pas de borne de ce côté.
  final int? minPriceFcfa;
  final int? maxPriceFcfa;
  final bool inStockOnly;

  /// Vide : aucune restriction sur cet axe. Sinon, un produit passe s'il
  /// a l'une des valeurs choisies.
  final Set<ProductCategory> categories;
  final Set<String> supplierIds;

  /// Un filtre, sans compter le tri : c'est ce qui peut vider une liste.
  bool get hasFilter =>
      minPriceFcfa != null ||
      maxPriceFcfa != null ||
      inStockOnly ||
      categories.isNotEmpty ||
      supplierIds.isNotEmpty;

  /// Un filtre ou un tri autre que la pertinence : le point sur l'icône.
  bool get isActive => hasFilter || sort != ProductSortOption.relevance;

  ProductListFilters copyWith({
    ProductSortOption? sort,
    bool? inStockOnly,
    Set<ProductCategory>? categories,
    Set<String>? supplierIds,
  }) => ProductListFilters(
    sort: sort ?? this.sort,
    minPriceFcfa: minPriceFcfa,
    maxPriceFcfa: maxPriceFcfa,
    inStockOnly: inStockOnly ?? this.inStockOnly,
    categories: categories ?? this.categories,
    supplierIds: supplierIds ?? this.supplierIds,
  );

  /// La fourchette de prix, l'une ou l'autre borne pouvant être levée.
  ProductListFilters withPriceRange(int? min, int? max) => ProductListFilters(
    sort: sort,
    minPriceFcfa: min,
    maxPriceFcfa: max,
    inStockOnly: inStockOnly,
    categories: categories,
    supplierIds: supplierIds,
  );

  /// Le prix d'une unité tel que la carte l'affiche.
  static int displayedPrice(Product product, {DateTime? now}) =>
      effectiveUnitPriceFcfa(
        basePriceFcfa: product.priceFcfa,
        promotions: product.promotions,
        quantity: 1,
        now: now,
      );

  bool matches(Product product, {DateTime? now}) {
    if (inStockOnly && product.stockQuantity <= 0) return false;
    if (categories.isNotEmpty && !categories.contains(product.category)) {
      return false;
    }
    if (supplierIds.isNotEmpty && !supplierIds.contains(product.supplierId)) {
      return false;
    }
    if (minPriceFcfa != null || maxPriceFcfa != null) {
      final prix = displayedPrice(product, now: now);
      if (minPriceFcfa != null && prix < minPriceFcfa!) return false;
      if (maxPriceFcfa != null && prix > maxPriceFcfa!) return false;
    }
    return true;
  }

  /// [products] filtrés puis triés. Le tri est stable : à égalité, l'ordre
  /// d'arrivée (celui de la pertinence) est gardé.
  List<Product> apply(Iterable<Product> products, {DateTime? now}) {
    final retenus = [
      for (final p in products)
        if (matches(p, now: now)) p,
    ];
    final comparer = _comparateur(now);
    if (comparer != null) mergeSort(retenus, compare: comparer);
    return retenus;
  }

  int Function(Product, Product)? _comparateur(DateTime? now) {
    int prix(Product p) => displayedPrice(p, now: now);
    int nom(Product a, Product b) =>
        normalizeForSearch(a.name).compareTo(normalizeForSearch(b.name));
    return switch (sort) {
      ProductSortOption.relevance => null,
      ProductSortOption.priceAsc => (a, b) => prix(a).compareTo(prix(b)),
      ProductSortOption.priceDesc => (a, b) => prix(b).compareTo(prix(a)),
      ProductSortOption.newest => (a, b) => b.createdAt.compareTo(a.createdAt),
      ProductSortOption.ratingDesc => (a, b) => b.ratingAverage.compareTo(
        a.ratingAverage,
      ),
      ProductSortOption.nameAsc => nom,
      ProductSortOption.nameDesc => (a, b) => nom(b, a),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ProductListFilters &&
      other.sort == sort &&
      other.minPriceFcfa == minPriceFcfa &&
      other.maxPriceFcfa == maxPriceFcfa &&
      other.inStockOnly == inStockOnly &&
      const SetEquality<ProductCategory>().equals(
        other.categories,
        categories,
      ) &&
      const SetEquality<String>().equals(other.supplierIds, supplierIds);

  @override
  int get hashCode => Object.hash(
    sort,
    minPriceFcfa,
    maxPriceFcfa,
    inStockOnly,
    Object.hashAllUnordered(categories),
    Object.hashAllUnordered(supplierIds),
  );
}

/// Le moins cher et le plus cher de [products] au prix affiché : les bornes
/// de la réglette. `null` pour une liste vide.
(int, int)? displayedPriceBounds(Iterable<Product> products, {DateTime? now}) {
  int? bas;
  int? haut;
  for (final p in products) {
    final prix = ProductListFilters.displayedPrice(p, now: now);
    if (bas == null || prix < bas) bas = prix;
    if (haut == null || prix > haut) haut = prix;
  }
  return bas == null ? null : (bas, haut!);
}
