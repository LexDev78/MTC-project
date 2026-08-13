import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

/// Raw `payout_requests`/`supplier_finance_settings` I/O. No Realtime (out
/// of scope, same "notify after my own write" shape as Lot 4's
/// datasources). Status transitions never write to `payout_requests`
/// directly — `updatePayoutStatus()` goes through the `security definer`
/// RPC `update_payout_status()` (`0005_payout_status_rpc.sql`), which
/// validates the transition before writing (a raw REST PATCH can't bypass
/// it, since there is no direct UPDATE policy on this table anymore).
class SupabaseSupplierFinanceDatasource {
  SupabaseSupplierFinanceDatasource(this._client);

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

  Stream<List<Map<String, dynamic>>> watchPayoutRequests(String supplierId) {
    return _watch(
      () => _client
          .from('payout_requests')
          .select()
          .eq('supplier_id', supplierId)
          .order('requested_at', ascending: false),
    );
  }

  Stream<List<Map<String, dynamic>>> watchAllPayoutRequests() {
    return _watch(
      () => _client.from('payout_requests').select().order('requested_at', ascending: false),
    );
  }

  Future<Map<String, dynamic>> requestPayout(Map<String, dynamic> row) async {
    final inserted = await _client
        .from('payout_requests')
        .insert({'id': IdGenerator.next(), 'status': 'requested', ...row})
        .select()
        .single();
    _notify();
    return inserted;
  }

  Future<Map<String, dynamic>> updatePayoutStatus({
    required String payoutId,
    required String status,
    String? rejectionReason,
  }) async {
    await _client.rpc(
      'update_payout_status',
      params: {
        'p_payout_id': payoutId,
        'p_status': status,
        'p_rejection_reason': rejectionReason,
      },
    );
    final updated = await _client
        .from('payout_requests')
        .select()
        .eq('id', payoutId)
        .single();
    _notify();
    return updated;
  }

  Future<Map<String, dynamic>?> getSettings(String supplierId) {
    return _client
        .from('supplier_finance_settings')
        .select()
        .eq('supplier_id', supplierId)
        .maybeSingle();
  }

  Future<void> updateSettings({
    required String supplierId,
    required double commissionRatePercent,
  }) async {
    await _client.from('supplier_finance_settings').upsert({
      'supplier_id': supplierId,
      'commission_rate_percent': commissionRatePercent,
    });
    _notify();
  }
}
