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

  Future<void> approve({required String id, required String staffId}) async {
    await _client
        .from('product_characteristic_types')
        .update({
          'status': 'approved',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by_staff_id': staffId,
          'rejection_reason': null,
        })
        .eq('id', id);
    _notify();
  }

  Future<void> reject({
    required String id,
    required String staffId,
    required String reason,
  }) async {
    await _client
        .from('product_characteristic_types')
        .update({
          'status': 'rejected',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by_staff_id': staffId,
          'rejection_reason': reason,
        })
        .eq('id', id);
    _notify();
  }
}
