import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visual_search_result.dart';

/// Appelle la fonction edge `visual-search`.
///
/// L'app envoie une photo et ne connaît ni modèle ni clé d'API : une clé
/// facturée à l'appel n'a rien à faire dans un binaire mobile, où elle
/// serait publique. Elle ne sait pas davantage comparer les vecteurs — la
/// base s'en charge, et ne les laisse pas sortir (`0083`, `0084`).
class SupabaseVisualSearchDatasource {
  const SupabaseVisualSearchDatasource(this._client);

  final SupabaseClient _client;

  /// [imageBytes] est encodée en data URL : c'est ce que le fournisseur
  /// d'empreintes accepte, et cela évite de déposer la photo dans un bucket
  /// pour une recherche qui ne la conserve pas.
  Future<VisualSearchResult> search({
    required Uint8List imageBytes,
    required String contentType,
    int limit = 24,
  }) async {
    final dataUrl = 'data:$contentType;base64,${base64Encode(imageBytes)}';

    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'visual-search',
        body: {'image': dataUrl, 'limit': limit},
      );
    } on FunctionException catch (e) {
      // La fonction répond un message en français pour chaque refus
      // (quota, modèle injoignable, photo trop lourde) : on l'affiche tel
      // quel plutôt que d'en inventer un moins précis.
      final details = e.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : 'La recherche par photo est indisponible.';
      throw VisualSearchException(message, quotaExhausted: e.status == 429);
    }

    final body = response.data as Map<String, dynamic>? ?? const {};
    return VisualSearchResult(
      remaining: (body['remaining'] as num?)?.toInt() ?? 0,
      matches: [
        for (final row in (body['results'] as List? ?? const []))
          (
            productId: (row as Map)['product_id'] as String,
            similarity: ((row)['similarity'] as num).toDouble(),
          ),
      ],
    );
  }
}
