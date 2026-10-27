import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `cart_items` table I/O — no `CartItem` entity knowledge here (see
/// `SupabaseCartRepository`, which maps rows via `CartItem.fromJson`, Lot 2).
class SupabaseCartDatasource {
  SupabaseCartDatasource(this._client);

  final SupabaseClient _client;

  /// No Realtime here (out of scope for this lot, see
  /// BACKEND_MIGRATION_PROGRESS.md) — re-fetches on every write made
  /// through this same repository instance, same shape as the in-memory
  /// datasource, backed by a real query.
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
    return _watch(() => _client.from('cart_items').select().eq('user_id', userId));
  }

  Future<void> addOrIncrement({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    required int quantity,
    String? variantId,
    String? variantName,
  }) async {
    // The dedup key includes `variant_id` — without it, two different
    // variants of the same product (e.g. two colors) would silently merge
    // into one line, showing whichever variant's name/price happened to be
    // snapshotted first for a quantity that's actually split across both.
    var query = _client
        .from('cart_items')
        .select()
        .eq('user_id', userId)
        .eq('product_id', productId);
    query = variantId == null
        ? query.isFilter('variant_id', null)
        : query.eq('variant_id', variantId);
    final existing = await query.maybeSingle();

    if (existing != null) {
      final newQuantity = (existing['quantity'] as int) + quantity;
      await _client
          .from('cart_items')
          .update({'quantity': newQuantity})
          .eq('id', existing['id'] as String);
    } else {
      await _client.from('cart_items').insert({
        'id': IdGenerator.next(),
        'user_id': userId,
        'product_id': productId,
        'supplier_id': supplierId,
        'product_name_snapshot': productName,
        'unit_price_fcfa_snapshot': unitPriceFcfa,
        'quantity': quantity,
        'variant_id': variantId,
        'variant_name_snapshot': variantName,
      });
    }
    _notify();
  }

  Future<void> updateQuantity({required String cartItemId, required int quantity}) async {
    await _client.from('cart_items').update({'quantity': quantity}).eq('id', cartItemId);
    _notify();
  }

  Future<void> removeItem(String cartItemId) async {
    await _client.from('cart_items').delete().eq('id', cartItemId);
    _notify();
  }

  Future<void> clear(String userId) async {
    await _client.from('cart_items').delete().eq('user_id', userId);
    _notify();
  }
}
