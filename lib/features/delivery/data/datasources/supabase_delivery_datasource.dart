import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/realtime_retry.dart';
import 'package:mtc_app/core/utils/stream_debounce.dart';

/// I/O brut des courses (`deliveries`, `0046_couriers_and_deliveries.sql`).
///
/// Comme `SupabaseOrderDatasource`, cette table est publiée en Realtime :
/// une course apparaît chez le livreur parce qu'un trigger serveur l'a créée
/// et attribuée, pas parce que l'app a demandé quelque chose. Un flux poussé
/// est donc la seule façon qu'il la voie arriver sans rafraîchir.
class SupabaseDeliveryDatasource {
  SupabaseDeliveryDatasource(this._client);

  final SupabaseClient _client;

  /// Course → commande → groupe fournisseur → fournisseur et lignes : tout ce
  /// que l'écran livreur affiche, en un aller-retour.
  /// Les alias ne sont ni `order` ni `group` : le premier est un paramètre de
  /// PostgREST (le tri), le second un mot-clé SQL. Avec eux, l'imbrication
  /// revient **vide** au lieu d'échouer — la requête passe, les champs
  /// manquent, et l'erreur n'apparaît qu'au moment de lire le résultat.
  static const _nestedSelect = '''
    *,
    order_data:orders (
      id, client_display_name_snapshot, client_phone_snapshot, alternate_phone,
      delivery_address_label, delivery_city, delivery_details,
      delivery_latitude, delivery_longitude, payment_method
    ),
    group_data:order_supplier_groups (
      id, supplier_name, delivery_fee_fcfa, subtotal_fcfa,
      supplier:suppliers (city, full_address, address_latitude, address_longitude, public_phone_numbers),
      items:order_items (product_name_snapshot, quantity, variant_name_snapshot)
    )
  ''';

  Future<List<Map<String, dynamic>>> _fetchForCourier(String courierId) async {
    final rows = await _client
        .from('deliveries')
        .select(_nestedSelect)
        // Les courses proposées *et* celles déjà acceptées : c'est la même
        // liste côté livreur, seul le statut change ce qu'on en fait.
        .or('courier_id.eq.$courierId,offered_to_courier_id.eq.$courierId')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Flux sans filtre côté Realtime, volontairement : `.stream()` n'accepte
  /// qu'une seule égalité, alors qu'une course intéresse le livreur par deux
  /// colonnes différentes (proposée à lui, ou acceptée par lui). La policy
  /// `deliveries_select_participants` ne lui laisse de toute façon voir que
  /// ces deux cas — le flux sert de déclencheur, le `select` ci-dessus fait
  /// le tri.
  Stream<List<Map<String, dynamic>>> watchForCourier(String courierId) {
    // Rafales regroupées : le flux n'a pas de filtre (voir ci-dessus), donc
    // chaque course créée ou avancée **ailleurs** déclenchait la lecture
    // imbriquée complète de ce livreur.
    return withRealtimeRetry(
      () => _client
          .from('deliveries')
          .stream(primaryKey: ['id'])
          .map((_) {})
          // Front montant : ce flux **est** la liste affichée, donc son
          // premier événement ne doit pas attendre la fenêtre.
          .debounceTriggers(leading: true)
          .asyncMap((_) => _fetchForCourier(courierId)),
    );
  }

  Future<void> accept(String deliveryId) {
    return _client.rpc('accept_delivery', params: {'p_delivery_id': deliveryId});
  }

  Future<void> decline(String deliveryId) {
    return _client.rpc('decline_delivery', params: {'p_delivery_id': deliveryId});
  }

  /// Relance les courses dont la fenêtre de réponse a expiré.
  ///
  /// Appelée à l'ouverture de la liste côté livreur : il n'y a pas de
  /// planificateur dans la base (ce serait `pg_cron` pour un besoin que le
  /// premier livreur qui ouvre son app couvre déjà).
  Future<void> reofferExpired() => _client.rpc('reoffer_expired_deliveries');

  /// Présente un code au serveur, qui décide seul de ce qu'il accuse (voir
  /// `scan_delivery_code`, `0051`). Renvoie le nouveau statut de la course.
  Future<String> scan({required String deliveryId, required String code}) async {
    final result = await _client.rpc(
      'scan_delivery_code',
      params: {'p_delivery_id': deliveryId, 'p_code': code},
    );
    return result as String;
  }

  /// Le code que *cet* utilisateur doit montrer : celui du retrait pour le
  /// fournisseur, celui de la remise pour le client. La policy de
  /// `delivery_codes` fait le tri — une requête qui ne renvoie rien signifie
  /// que l'appelant n'avait pas à le voir, pas qu'il n'existe pas.
  Future<String?> fetchCode({
    required String deliveryId,
    required String kind,
  }) async {
    final row = await _client
        .from('delivery_codes')
        .select('code, consumed_at')
        .eq('delivery_id', deliveryId)
        .eq('kind', kind)
        .maybeSingle();
    if (row == null || row['consumed_at'] != null) return null;
    return row['code'] as String;
  }

  /// Course rattachée à un groupe fournisseur, pour les écrans client et
  /// fournisseur qui partent de la commande et non de la course.
  Future<Map<String, dynamic>?> fetchByGroup(String supplierGroupId) {
    return _client
        .from('deliveries')
        .select('id, status')
        .eq('supplier_group_id', supplierGroupId)
        .maybeSingle();
  }

  /// Une seule écriture pour deux usages : la fiche du livreur (attribution
  /// au plus proche) et sa course en cours (suivi client). Voir
  /// `push_courier_position`, `0052`.
  Future<void> pushPosition({
    required double latitude,
    required double longitude,
  }) {
    return _client.rpc(
      'push_courier_position',
      params: {'p_latitude': latitude, 'p_longitude': longitude},
    );
  }

  /// Livreurs en attente de validation, pour le staff. Le tri est le même
  /// que la file des dossiers fournisseurs : le plus ancien d'abord, pour
  /// que personne n'attende indéfiniment derrière des arrivées plus récentes.
  Future<List<Map<String, dynamic>>> fetchPendingCouriers() async {
    final rows = await _client
        .from('couriers')
        // Aucune jointure : la fiche porte elle-même l'identité du livreur
        // (`0053_courier_identity.sql`). Passer par `profiles` était à la
        // fois ambigu — deux clés étrangères — et vain, puisque cette table
        // n'est lisible que par son propriétaire.
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> reviewCourier({
    required String courierId,
    required bool approve,
    String? reason,
  }) {
    return _client.rpc(
      'review_courier',
      params: {
        'p_courier_id': courierId,
        'p_approve': approve,
        'p_reason': reason,
      },
    );
  }

  /// Historique des courses terminées, **sans** les identités du client ni
  /// du fournisseur (`fetch_courier_delivery_history`, `0060`).
  ///
  /// Pourquoi une RPC alors que `watchForCourier` ramène déjà ces courses :
  /// cette lecture-là remonte commande, client et fournisseur. Rejouer un
  /// filtre d'affichage par-dessus laisserait les coordonnées arriver sur
  /// l'appareil, où il suffirait d'un écran oublié pour les montrer.
  Future<List<Map<String, dynamic>>> fetchHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'fetch_courier_delivery_history',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<Map<String, dynamic>?> fetchStats() async {
    final rows = await _client.rpc('fetch_courier_stats');
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? null : list.first;
  }

  /// Les notes reçues. Ne renvoie jamais `rater_id` : le livreur voit d'où
  /// vient la note, pas de qui.
  Future<List<Map<String, dynamic>>> fetchMyRatings({
    int limit = 30,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'fetch_my_courier_ratings',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Note une course livrée. Le rôle (client ou fournisseur) n'est pas
  /// transmis : le serveur le déduit de l'appelant, sinon le client pourrait
  /// déposer une note « fournisseur » et en poser deux.
  Future<void> rateCourier({
    required String deliveryId,
    required int stars,
    String? comment,
  }) {
    return _client.rpc(
      'rate_courier',
      params: {
        'p_delivery_id': deliveryId,
        'p_stars': stars,
        'p_comment': comment,
      },
    );
  }

  Future<Map<String, dynamic>?> fetchMyRatingForDelivery(
    String deliveryId,
  ) async {
    final rows = await _client.rpc(
      'fetch_my_rating_for_delivery',
      params: {'p_delivery_id': deliveryId},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    return list.isEmpty ? null : list.first;
  }

  Future<void> setOnline({
    required String courierId,
    required bool isOnline,
    double? latitude,
    double? longitude,
  }) {
    return _client
        .from('couriers')
        .update({
          'is_online': isOnline,
          if (latitude != null) 'last_latitude': latitude,
          if (longitude != null) 'last_longitude': longitude,
          if (latitude != null) 'last_position_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', courierId);
  }
}
