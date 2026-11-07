import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `product_comments`/`comment_likes` I/O. Reads always go through the
/// `product_comments_with_likes` view (`0001_initial_schema.sql`) — its
/// `array_agg`'d `liked_by_user_ids` column lines up exactly with
/// `ProductComment.fromJson`'s generated key, so no manual hydration is
/// needed here (unlike `SupplierKyc`, Lot 6). No Realtime (out of scope,
/// same "notify after my own write" shape as Lot 4's datasources).
class SupabaseProductCommentDatasource {
  SupabaseProductCommentDatasource(this._client);

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

  Stream<List<Map<String, dynamic>>> watchForProduct(String productId) {
    return _watch(
      () => _client
          .from('product_comments_with_likes')
          .select()
          .eq('product_id', productId)
          .order('created_at', ascending: true),
    );
  }

  Stream<List<Map<String, dynamic>>> watchForSupplier(String supplierId) {
    return _watch(
      () => _client
          .from('product_comments_with_likes')
          .select()
          .eq('supplier_id', supplierId)
          .order('created_at', ascending: true),
    );
  }

  Future<void> addComment(Map<String, dynamic> row) async {
    await _client.from('product_comments').insert({'id': IdGenerator.next(), ...row});
    _notify();
  }

  Future<void> toggleLike({required String commentId, required String userId}) async {
    final existing = await _client
        .from('comment_likes')
        .select()
        .eq('comment_id', commentId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await _client
          .from('comment_likes')
          .insert({'comment_id': commentId, 'user_id': userId});
    } else {
      await _client
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);
    }
    _notify();
  }
}
