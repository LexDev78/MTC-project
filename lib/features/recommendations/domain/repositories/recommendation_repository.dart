import '../../../catalog/domain/entities/product_category.dart';
import '../entities/recent_search.dart';
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

  /// Les recherches du compte connecté, la plus récente d'abord. Lues dans
  /// le même journal que les signaux ci-dessus : c'est ce que l'app retient
  /// de lui, et qu'il peut effacer.
  ///
  /// Contrairement aux signaux, une lecture ou un effacement qui échoue
  /// remonte son erreur : l'écran doit pouvoir le dire.
  Future<List<RecentSearch>> fetchRecentSearches({int limit});

  /// Efface [query] (toutes ses occurrences, casse et accents confondus),
  /// ou toutes les recherches quand [query] est nul. Rend le nombre
  /// d'entrées effacées du journal.
  Future<int> forgetSearches({String? query});
}
