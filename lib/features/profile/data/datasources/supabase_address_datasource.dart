import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw `addresses` I/O — no `Address` entity knowledge here. No Realtime
/// (out of scope, same "notify after my own write" shape as Lot 4's
/// datasources).
class SupabaseAddressDatasource {
  SupabaseAddressDatasource(this._client);

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

  Stream<List<Map<String, dynamic>>> watchForUser(String userId) {
    return _watch(
      () => _client.from('addresses').select().eq('user_id', userId),
    );
  }

  Future<Map<String, dynamic>> add(Map<String, dynamic> row) async {
    final inserted = await _client.from('addresses').insert(row).select().single();
    _notify();
    return inserted;
  }

  Future<void> remove(String addressId) async {
    await _client.from('addresses').delete().eq('id', addressId);
    _notify();
  }

  /// Repose le point d'une adresse. La RLS limite déjà l'appelant à ses
  /// propres adresses ; la date de confirmation est posée par un trigger
  /// (`0079`), pas envoyée d'ici.
  Future<void> updatePosition({
    required String addressId,
    required double latitude,
    required double longitude,
  }) async {
    await _client
        .from('addresses')
        .update({'latitude': latitude, 'longitude': longitude})
        .eq('id', addressId);
  }
}
