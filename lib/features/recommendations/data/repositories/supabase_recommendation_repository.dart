import '../../../catalog/domain/entities/product_category.dart';
import '../../../catalog/domain/repositories/product_repository.dart';
import '../../domain/entities/suggestion_reason.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../datasources/supabase_recommendation_datasource.dart';

class SupabaseRecommendationRepository implements RecommendationRepository {
  SupabaseRecommendationRepository(this._datasource, this._products);

  final SupabaseRecommendationDatasource _datasource;
  final ProductRepository _products;

  @override
  Future<List<ProductSuggestion>> fetchSuggestions({int limit = 24}) async {
    final rows = await _datasource.fetchSuggestions(limit: limit);
    if (rows.isEmpty) return const [];

    // Deux lectures et pas une : la fonction classe, `fetchByIds` rend les
    // produits complets (promotions imbriquées comprises). Voir l'en-tête de
    // `0082` pour pourquoi la base ne rend pas directement des lignes de
    // `products`.
    final products = await _products.fetchByIds([
      for (final row in rows) row.productId,
    ]);

    // `fetchByIds` préserve l'ordre demandé mais peut rendre moins de
    // produits (un produit devenu invisible entre les deux appels). On
    // repart donc des produits obtenus, en retrouvant leur raison.
    final reasonById = {
      for (final row in rows) row.productId: SuggestionReason.fromDb(row.reason),
    };
    return [
      for (final product in products)
        (product: product, reason: reasonById[product.id]),
    ];
  }

  @override
  Future<void> logProductView(String productId) =>
      _datasource.logEvent(kind: 'product_view', productId: productId);

  @override
  Future<void> logCategoryOpen(ProductCategory category) =>
      _datasource.logEvent(kind: 'category_open', category: category);

  @override
  Future<void> logSearch(String query) {
    final trimmed = query.trim();
    // Une recherche vide n'est pas un signal — c'est un champ qu'on vide.
    if (trimmed.isEmpty) return Future.value();
    return _datasource.logEvent(kind: 'search', query: trimmed);
  }

  @override
  Future<void> logCartAdd(String productId) =>
      _datasource.logEvent(kind: 'cart_add', productId: productId);
}
