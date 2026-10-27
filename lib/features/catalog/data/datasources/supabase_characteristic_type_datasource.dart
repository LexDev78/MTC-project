import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `product_characteristic_types` I/O — no entity knowledge here (see
/// `SupabaseCharacteristicTypeRepository`). Same "no Realtime, notify after
/// my own write" shape as every other Supabase datasource in this app.
class SupabaseCharacteristicTypeDatasource {
  SupabaseCharacteristicTypeDatasource(this._client);

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

  Stream<List<Map<String, dynamic>>> watchApproved() {
    return _watch(
      () => _client
          .from('product_characteristic_types')
          .select()
          .eq('status', 'approved')
          .order('label', ascending: true),
    );
  }

  Stream<List<Map<String, dynamic>>> watchQueue() {
    return _watch(
      () => _client
          .from('product_characteristic_types')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true),
    );
  }

  Future<void> propose({required String supplierId, required String label}) async {
    await _client.from('product_characteristic_types').insert({
      'id': IdGenerator.next(),
      'label': label,
      'status': 'pending',
      'proposed_by_supplier_id': supplierId,
    });
    _notify();
  }

  /// Décide par `review_characteristic_type` (`0069`).
  ///
  /// La notification qui accompagne la décision partait de l'app, ce qui
  /// obligeait à laisser une session insérer des notifications. Elle part
  /// désormais avec l'écriture qu'elle annonce, et `staffId` n'est plus
  /// transmis : le serveur prend l'appelant.
  Future<void> review({
    required String id,
    required bool approve,
    String? reason,
  }) async {
    await _client.rpc(
      'review_characteristic_type',
      params: {'p_id': id, 'p_approve': approve, 'p_reason': reason},
    );
    _notify();
  }
}
