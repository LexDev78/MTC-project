import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../catalog/data/datasources/supabase_product_datasource.dart'
    show categoryToDb;
import '../../../catalog/domain/entities/product_category.dart';

/// Une suggestion telle que la base la rend : un identifiant et une raison,
/// sans le produit. La résolution en `Product` se fait un étage plus haut.
typedef SuggestionRow = ({String productId, String reason});

class SupabaseRecommendationDatasource {
  SupabaseRecommendationDatasource(this._client);

  final SupabaseClient _client;

  /// `get_recommended_products` (`0082`) — déjà trié, déjà dédoublonné,
  /// déjà restreint aux produits visibles.
  Future<List<SuggestionRow>> fetchSuggestions({required int limit}) async {
    final rows = await _client.rpc(
      'get_recommended_products',
      params: {'p_limit': limit},
    );
    return [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        (productId: row['product_id'] as String, reason: row['reason'] as String),
    ];
  }

  /// `log_activity_event` (`0081`) estampille `user_id` lui-même : l'app ne
  /// transmet jamais d'identité, et ne *peut* pas en transmettre une autre.
  ///
  /// Les erreurs sont avalées, délibérément. Journaliser est un effet de
  /// bord : une fiche produit qui s'est affichée correctement ne doit pas
  /// remonter une erreur parce que la trace n'est pas partie. Le cas courant
  /// n'est même pas une panne — c'est une session hors ligne, où la trace
  /// n'a aucune valeur de rattrapage (une consultation d'il y a trois heures
  /// ne dit plus rien de l'intention du moment), donc rien à rejouer.
  Future<void> logEvent({
    required String kind,
    String? productId,
    ProductCategory? category,
    String? query,
  }) async {
    try {
      await _client.rpc(
        'log_activity_event',
        params: {
          'p_kind': kind,
          'p_product_id': productId,
          'p_category': category == null ? null : categoryToDb(category),
          'p_query': query,
        },
      );
    } catch (_) {
      // Volontairement muet — voir le commentaire ci-dessus.
    }
  }

  /// `consume_ai_quota` (`0081`) : incrémente et tranche en une instruction.
  /// Rend le nombre d'appels restants, ou -1 si le plafond du jour est
  /// atteint. Réservé à la recherche par photo.
  Future<int> consumeVisualSearchQuota({required int dailyLimit}) async {
    final remaining = await _client.rpc(
      'consume_ai_quota',
      params: {'p_feature': 'visual_search', 'p_daily_limit': dailyLimit},
    );
    return (remaining as num?)?.toInt() ?? -1;
  }
}
