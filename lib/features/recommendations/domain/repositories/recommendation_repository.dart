import '../../../catalog/domain/entities/product_category.dart';
import '../entities/suggestion_reason.dart';

abstract interface class RecommendationRepository {
  /// Le fil « Pour vous » : des produits visibles, classés, chacun avec sa
  /// justification. Réservé aux comptes connectés : `anon` n'a pas le droit
  /// d'exécuter la fonction, et c'est `recommendedFeedProvider` qui rend une
  /// liste vide sans appeler quand personne n'est connecté.
  ///
  /// Jamais vide pour un compte connecté dès que le catalogue contient un
  /// produit visible : la source « populaire » sert de filet (voir `0082`).
  Future<List<ProductSuggestion>> fetchSuggestions({int limit});

  /// Les quatre signaux que le journal retient. Tous sont des **effets de
  /// bord** du parcours : ils ne doivent jamais faire échouer l'écran qui
  /// les déclenche, et leurs implémentations avalent donc leurs erreurs.
  /// Appeler sans `await` est un usage normal.
  Future<void> logProductView(String productId);
  Future<void> logCategoryOpen(ProductCategory category);
  Future<void> logSearch(String query);
  Future<void> logCartAdd(String productId);
}
