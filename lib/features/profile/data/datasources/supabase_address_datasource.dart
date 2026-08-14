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
}
