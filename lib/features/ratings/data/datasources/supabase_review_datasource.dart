import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `reviews` I/O — no `Review` entity knowledge here. No Realtime (out
/// of scope, same "notify after my own write" shape as Lot 4's
/// datasources).
class SupabaseReviewDatasource {
  SupabaseReviewDatasource(this._client);

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

  Stream<List<Map<String, dynamic>>> watchForSupplier(String supplierId) {
    return _watch(
      () => _client
          .from('reviews')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: false),
    );
  }

  Future<void> submitReview(Map<String, dynamic> row) async {
    await _client.from('reviews').insert({'id': IdGenerator.next(), ...row});
    _notify();
  }

  Future<bool> hasReview({
    required String orderId,
    required String supplierGroupId,
  }) async {
    final existing = await _client
        .from('reviews')
        .select('id')
        .eq('order_id', orderId)
        .eq('supplier_group_id', supplierGroupId)
        .maybeSingle();
    return existing != null;
  }

  Future<Map<String, dynamic>?> getById(String reviewId) {
    return _client.from('reviews').select().eq('id', reviewId).maybeSingle();
  }

  Future<void> reply({
    required String reviewId,
    required String reply,
  }) async {
    await _client
        .from('reviews')
        .update({
          'supplier_reply': reply,
          'supplier_replied_at': DateTime.now().toIso8601String(),
        })
        .eq('id', reviewId);
    _notify();
  }
}
