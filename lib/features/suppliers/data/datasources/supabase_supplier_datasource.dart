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

  Future<Map<String, dynamic>> getById(String id) {
    return _client.from('suppliers').select().eq('id', id).single();
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
}
