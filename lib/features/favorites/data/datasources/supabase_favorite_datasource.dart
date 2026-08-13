import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `favorites` table I/O — no `Favorite` entity knowledge here (see
/// `SupabaseFavoriteRepository`, which maps rows via `Favorite.fromJson`,
/// Lot 2).
class SupabaseFavoriteDatasource {
  SupabaseFavoriteDatasource(this._client);

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
    return _watch(() => _client.from('favorites').select().eq('user_id', userId));
  }

  Future<void> add({required String userId, required String productId}) async {
    await _client.from('favorites').insert({
      'id': IdGenerator.next(),
      'user_id': userId,
      'product_id': productId,
    });
    _notify();
  }

  Future<void> remove({required String userId, required String productId}) async {
    await _client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('product_id', productId);
    _notify();
  }
}
