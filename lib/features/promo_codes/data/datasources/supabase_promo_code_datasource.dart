import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// I/O brut des codes promo (`0071`, `0072`).
///
/// Deux chemins volontairement différents :
///
///  * le **fournisseur** écrit directement dans `promo_codes` — la policy ne
///    lui ouvre que les siens, et un trigger pose le propriétaire depuis la
///    session ;
///  * le **client** ne lit jamais la table. Aucune policy ne la lui ouvre,
///    sans quoi il listerait tous les codes en vigueur de toutes les
///    boutiques. Il passe par `preview_promo_code`, qui répond sur un code
///    **présenté**, jamais sur l'ensemble.
class SupabasePromoCodeDatasource {
  SupabasePromoCodeDatasource(this._client);

  final SupabaseClient _client;

  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  /// Les codes du fournisseur, avec leurs utilisations et le détail de ce
  /// qu'elles ont remisé — en une lecture plutôt qu'en trois requêtes
  /// imbriquées depuis l'app.
  Stream<List<Map<String, dynamic>>> watchMine() {
    return _watch(() async {
      final rows = await _client.rpc('fetch_my_promo_codes');
      return List<Map<String, dynamic>>.from(rows as List);
    });
  }

  /// `supplier_id` n'est pas transmis : un trigger le pose depuis la session
  /// (`stamp_promo_code_supplier`), et le code est normalisé en majuscules.
  Future<String> create(Map<String, dynamic> row) async {
    final inserted = await _client
        .from('promo_codes')
        .insert(row)
        .select('id')
        .single();
    _notify();
    return inserted['id'] as String;
  }

  /// Remplace la couverture : aucune ligne = tous les produits du
  /// fournisseur.
  Future<void> setProducts({
    required String promoCodeId,
    required List<String> productIds,
  }) async {
    await _client
        .from('promo_code_products')
        .delete()
        .eq('promo_code_id', promoCodeId);
    if (productIds.isNotEmpty) {
      await _client.from('promo_code_products').insert([
        for (final id in productIds)
          {'promo_code_id': promoCodeId, 'product_id': id},
      ]);
    }
    _notify();
  }

  /// Corrige un code existant. Le **code lui-même** n'en fait jamais
  /// partie : il est imprimé sur des affiches et envoyé par message, et
  /// `promo_code_redemptions` en garde une copie pour l'historique. Le
  /// changer laisserait sans recours tous ceux qui tiennent l'ancien.
  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _client.from('promo_codes').update(patch).eq('id', id);
    _notify();
  }

  Future<void> setActive({required String id, required bool isActive}) async {
    await _client
        .from('promo_codes')
        .update({'is_active': isActive})
        .eq('id', id);
    _notify();
  }

  Future<void> delete(String id) async {
    await _client.from('promo_codes').delete().eq('id', id);
    _notify();
  }

  /// Ce qu'un code vaut sur ces lignes, sans rien consommer : l'appel peut
  /// être rejoué autant de fois que le client retape son code.
  /// « Existe-t-il un code utilisable pour ces produits ? », sans dire
  /// lequel (`cart_has_promo_code`, `0089`).
  ///
  /// Un booléen et non une liste : le client ne doit pas pouvoir énumérer
  /// les codes en vigueur, sinon il récupérerait des remises qu'on ne lui a
  /// pas adressées.
  Future<bool> existsForProducts(List<String> productIds) async {
    final result = await _client.rpc(
      'cart_has_promo_code',
      params: {'p_product_ids': productIds},
    );
    return result == true;
  }

  Future<Map<String, dynamic>> preview({
    required String code,
    required List<Map<String, dynamic>> lines,
  }) async {
    final result = await _client.rpc(
      'preview_promo_code',
      params: {'p_code': code, 'p_lines': lines},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  /// Les codes utilisés sur une commande, par groupe fournisseur.
  ///
  /// Passe par une RPC parce que la trace ne porte qu'un identifiant de
  /// code : `promo_codes` est fermée au client — c'est ce qui l'empêche
  /// d'énumérer les codes en vigueur — et le libellé vient donc de
  /// l'instantané figé à la commande.
  Future<List<Map<String, dynamic>>> fetchForOrder(String orderId) async {
    final rows = await _client.rpc(
      'fetch_order_promo_codes',
      params: {'p_order_id': orderId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
