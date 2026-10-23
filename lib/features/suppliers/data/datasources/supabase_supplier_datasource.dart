import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw `suppliers` table I/O — no `SupplierProfile` knowledge here (see
/// `SupabaseSupplierRepository`, which maps rows to/from the domain
/// entity via `SupplierProfile.fromJson`/`toJson`, Lot 2).
class SupabaseSupplierDatasource {
  SupabaseSupplierDatasource(this._client);

  final SupabaseClient _client;

  /// No Realtime here (out of scope for this lot, see
  /// BACKEND_MIGRATION_PROGRESS.md) — re-fetches on every write made
  /// through this same repository instance, same "notify after mutation"
  /// shape the in-memory datasource used, just backed by a real query
  /// instead of an in-memory list.
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(Future<T> Function() fetch) {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changes.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).asyncMap((_) => fetch());
  }

  void _notify() => _changes.add(null);

  Stream<List<Map<String, dynamic>>> watchByType(String supplierType) {
    return _watch(
      () => _client.from('suppliers').select().eq('supplier_type', supplierType),
    );
  }

  /// Avec `listed_product_count` (`0123`), le nombre de produits que la
  /// vitrine annonce au client — une fonction, que `*` n'inclut pas.
  Future<Map<String, dynamic>> getById(String id) {
    return _client
        .from('suppliers')
        .select('*, listed_product_count')
        .eq('id', id)
        .single();
  }

  Stream<List<Map<String, dynamic>>> watchTopRated({required int limit}) {
    return _watch(
      () => _client
          .from('suppliers')
          .select()
          .or('verification_status.eq.verified,verification_status.is.null')
          .order('rating_average', ascending: false)
          .limit(limit),
    );
  }

  /// Les boutiques qu'un client peut visiter : celles dont l'identité est
  /// vérifiée — leurs produits sont les seuls qu'il voit
  /// (`products_select_public`) —, et MTC Officiel. Une boutique en attente
  /// ou refusée n'aurait qu'une vitrine vide à montrer.
  ///
  /// Nommer `principal` plutôt que « sans statut » : un statut nul sur une
  /// boutique tierce la ferait passer pour vérifiée.
  Future<List<Map<String, dynamic>>> fetchListed() {
    return _client
        .from('suppliers')
        .select('*, listed_product_count')
        .or('verification_status.eq.verified,supplier_type.eq.principal')
        .order('business_name');
  }

  Future<Map<String, dynamic>> add(Map<String, dynamic> row) async {
    final inserted = await _client.from('suppliers').insert(row).select().single();
    _notify();
    return inserted;
  }

  Future<({double average, int count})> recordReview({
    required String supplierId,
    required int stars,
  }) async {
    final current = await getById(supplierId);
    final oldAverage = (current['rating_average'] as num).toDouble();
    final oldCount = current['rating_count'] as int;
    final newCount = oldCount + 1;
    final newAverage = ((oldAverage * oldCount) + stars) / newCount;

    await _client
        .from('suppliers')
        .update({'rating_average': newAverage, 'rating_count': newCount})
        .eq('id', supplierId);
    _notify();
    return (average: newAverage, count: newCount);
  }

  Future<void> updateVerificationStatus(String supplierId, String status) async {
    await _client
        .from('suppliers')
        .update({'verification_status': status})
        .eq('id', supplierId);
    _notify();
  }

  Future<void> adjustProductCount(String supplierId, int delta) async {
    final current = await getById(supplierId);
    final newCount = (current['product_count'] as int) + delta;
    await _client
        .from('suppliers')
        .update({'product_count': newCount})
        .eq('id', supplierId);
    _notify();
  }

  Future<void> updateStorefront({
    required String supplierId,
    required Map<String, dynamic> fields,
  }) async {
    await _client.from('suppliers').update(fields).eq('id', supplierId);
    _notify();
  }

  Future<void> setOpen(String supplierId, bool isOpen) async {
    await _client.from('suppliers').update({'is_open': isOpen}).eq('id', supplierId);
    _notify();
  }

  /// Les chiffres du tableau de bord, comptés côté serveur (`0092`).
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final row = await _client.rpc('fetch_supplier_dashboard_stats');
    return Map<String, dynamic>.from(row as Map);
  }

  /// L'équipe de la boutique (`0093`). Réservé au propriétaire : la RPC
  /// rend une liste vide à un collaborateur plutôt que de lui montrer ses
  /// collègues et leurs accès.
  Future<List<Map<String, dynamic>>> fetchCollaborators() async {
    final rows = await _client.rpc('fetch_my_collaborators');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Crée le compte d'un collaborateur.
  ///
  /// Par une fonction edge et non depuis l'app : `auth.signUp` remplacerait
  /// la session du patron par celle de l'employé qu'il vient de créer.
  Future<({String userId, String temporaryPassword})> createCollaborator({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required Set<String> permissions,
  }) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-collaborator',
        body: {
          'displayName': displayName,
          'usernameOrPhone': usernameOrPhone,
          'phoneNumber': phoneNumber,
          'permissions': permissions.toList(),
        },
      );
    } on FunctionException catch (e) {
      // La fonction répond un message en français pour chaque refus — nom
      // déjà pris, mot de passe trop court, appelant qui n'est pas
      // propriétaire. On l'affiche tel quel.
      final details = e.details;
      throw Exception(
        details is Map && details['error'] is String
            ? details['error'] as String
            : 'Impossible de créer ce compte.',
      );
    }
    final body = response.data as Map<String, dynamic>? ?? const {};
    // Le mot de passe n'est rendu qu'ici, une seule fois : il n'est stocké
    // nulle part en clair, et aucune autre requête ne permettra de le
    // relire. L'écran doit donc le montrer tout de suite.
    return (
      userId: body['user_id'] as String? ?? '',
      temporaryPassword: body['temporary_password'] as String? ?? '',
    );
  }

  Future<void> setCollaboratorPermissions({
    required String userId,
    required Set<String> permissions,
  }) async {
    await _client.rpc(
      'set_collaborator_permissions',
      params: {'p_user_id': userId, 'p_permissions': permissions.toList()},
    );
  }

  /// Retire l'accès (`0110`) : la ligne reste, désactivée.
  Future<void> removeCollaborator(String userId) async {
    await _client.rpc(
      'remove_supplier_collaborator',
      params: {'p_user_id': userId},
    );
  }

  /// Rétablit l'accès d'un collaborateur retiré, avec ses permissions
  /// d'avant.
  Future<void> reactivateCollaborator(String userId) async {
    await _client.rpc(
      'reactivate_supplier_collaborator',
      params: {'p_user_id': userId},
    );
  }
}
