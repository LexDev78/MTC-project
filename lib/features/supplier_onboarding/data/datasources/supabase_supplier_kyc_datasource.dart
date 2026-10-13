import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `supplier_kyc`/`supplier_documents` I/O — no `SupplierKyc` entity
/// knowledge here (see `SupabaseSupplierKycRepository`, which hydrates the
/// sealed union manually, since the flattened table + variant discriminator
/// has no generated `fromJson`, Lot 2). No Realtime (out of scope, same
/// "notify after my own write" shape as Lot 4's datasources).
class SupabaseSupplierKycDatasource {
  SupabaseSupplierKycDatasource(this._client);

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

  static const _nestedSelect = '*, documents:supplier_documents(*)';

  Future<Map<String, dynamic>?> _fetchOne(String supplierId) {
    return _client
        .from('supplier_kyc')
        .select(_nestedSelect)
        .eq('supplier_id', supplierId)
        .maybeSingle();
  }

  Stream<Map<String, dynamic>?> watchForSupplier(String supplierId) {
    return _watch(() => _fetchOne(supplierId));
  }

  Future<Map<String, dynamic>> getForSupplier(String supplierId) {
    return _client
        .from('supplier_kyc')
        .select(_nestedSelect)
        .eq('supplier_id', supplierId)
        .single();
  }

  Future<Map<String, dynamic>> getById(String kycId) {
    return _client.from('supplier_kyc').select(_nestedSelect).eq('id', kycId).single();
  }

  Stream<List<Map<String, dynamic>>> watchQueue(List<String> statuses) {
    return _watch(
      () => _client
          .from('supplier_kyc')
          .select(_nestedSelect)
          .inFilter('status', statuses)
          .order('submitted_at', ascending: true),
    );
  }

  Future<void> saveDraftCompany({
    required String supplierId,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) async {
    final existing = await _client
        .from('supplier_kyc')
        .select('id')
        .eq('supplier_id', supplierId)
        .maybeSingle();

    if (existing == null) {
      await _client.from('supplier_kyc').insert({
        'id': IdGenerator.next(),
        'supplier_id': supplierId,
        'legal_type': 'company',
        'status': 'draft',
        'rccm_number': rccmNumber,
        'tax_id': taxId,
        'legal_representative_name': legalRepresentativeName,
        'registered_address': registeredAddress,
      });
    } else {
      final fields = <String, dynamic>{
        if (rccmNumber != null) 'rccm_number': rccmNumber,
        if (taxId != null) 'tax_id': taxId,
        if (legalRepresentativeName != null)
          'legal_representative_name': legalRepresentativeName,
        if (registeredAddress != null) 'registered_address': registeredAddress,
      };
      if (fields.isNotEmpty) {
        await _client
            .from('supplier_kyc')
            .update(fields)
            .eq('id', existing['id'] as String);
      }
    }
    _notify();
  }

  Future<void> saveDraftIndividual({required String supplierId}) async {
    final existing = await _client
        .from('supplier_kyc')
        .select('id')
        .eq('supplier_id', supplierId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('supplier_kyc').insert({
        'id': IdGenerator.next(),
        'supplier_id': supplierId,
        'legal_type': 'individual',
        'status': 'draft',
      });
      _notify();
    }
  }

  Future<void> addDocument({
    required String supplierId,
    required String type,
    required String filePath,
  }) async {
    final kyc = await _client
        .from('supplier_kyc')
        .select('id')
        .eq('supplier_id', supplierId)
        .single();
    final kycId = kyc['id'] as String;
    // Replaces any existing document of the same type rather than
    // accumulating duplicates, same as the in-memory datasource.
    await _client
        .from('supplier_documents')
        .delete()
        .eq('kyc_id', kycId)
        .eq('type', type);
    await _client.from('supplier_documents').insert({
      'id': IdGenerator.next(),
      'kyc_id': kycId,
      'type': type,
      'file_path': filePath,
    });
    _notify();
  }

  Future<void> removeDocument({required String documentId}) async {
    await _client.from('supplier_documents').delete().eq('id', documentId);
    _notify();
  }

  Future<void> setConsent({
    required String supplierId,
    required String policyVersion,
  }) async {
    await _client
        .from('supplier_kyc')
        .update({
          'consent_accepted': true,
          'consent_accepted_at': DateTime.now().toUtc().toIso8601String(),
          'consent_policy_version': policyVersion,
        })
        .eq('supplier_id', supplierId);
    _notify();
  }

  /// Soumet le dossier par `submit_supplier_kyc` (`0075`).
  ///
  /// Le statut n'est plus écrit à la main : les colonnes de décision sont
  /// sorties des droits d'écriture, parce qu'un fournisseur pouvait passer
  /// son propre dossier à `approved` — sa boutique n'en devenait pas
  /// vérifiée, mais son dossier quittait la file du staff et plus personne
  /// ne l'examinait.
  ///
  /// `supplierId` n'est plus transmis : le serveur prend le fournisseur en
  /// activité.
  Future<void> submit() async {
    await _client.rpc('submit_supplier_kyc');
    _notify();
  }

  /// Prend le dossier en examen (`start_kyc_review`). L'agent est celui de
  /// la session : on ne s'attribue pas le dossier d'un collègue.
  Future<void> startReview({required String kycId}) async {
    await _client.rpc('start_kyc_review', params: {'p_kyc_id': kycId});
    _notify();
  }

  /// Décide du dossier par `review_supplier_kyc` (`0069`) et non par un
  /// `update`.
  ///
  /// Une décision touchait quatre enregistrements — le dossier, la fiche
  /// fournisseur, tous ses produits, la notification — en quatre appels
  /// depuis l'app. Un échec au milieu laissait un dossier approuvé dont les
  /// produits restaient invisibles, état qu'aucun écran ne sait rattraper.
  /// Les quatre tiennent maintenant dans une transaction, et `staffId` n'est
  /// plus transmis : le serveur prend l'appelant.
  Future<void> review({
    required String kycId,
    required bool approve,
    String? reason,
  }) async {
    await _client.rpc(
      'review_supplier_kyc',
      params: {
        'p_kyc_id': kycId,
        'p_approve': approve,
        'p_reason': reason,
      },
    );
    _notify();
  }
}
