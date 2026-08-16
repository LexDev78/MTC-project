import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/utils/realtime_retry.dart';

/// Raw `orders`/`order_supplier_groups`/`order_items` I/O — no `Order`
/// entity knowledge here (see `SupabaseOrderRepository`, which maps rows
/// via `Order.fromJson`, Lot 2). Unlike the other Lot 4/5 datasources,
/// this one uses real Postgres Realtime (`.stream()`) rather than a
/// "notify after my own write" broadcast — several independent parties
/// (client, supplier(s), staff) need to see each other's changes, not
/// just their own (see BACKEND_MIGRATION_PROGRESS.md, Lot 5). Every write
/// goes through the two `security definer` RPCs
/// (`supabase/migrations/0003_orders_rpc.sql`) — `orders`/
/// `order_supplier_groups`/`order_items` have no INSERT/UPDATE RLS policy
/// at all, so a direct table write is never possible, even for the owner.
class SupabaseOrderDatasource {
  SupabaseOrderDatasource(this._client);

  final SupabaseClient _client;

  /// `order_supplier_groups`' own RLS already scopes the embedded array to
  /// whichever groups the calling role is allowed to see (owner supplier,
  /// the order's client, or an admin) — the same privacy boundary
  /// `SupplierOrderView` already imposed in Dart, now imposed by Postgres
  /// itself (verified in Lot 1). No extra filtering needed here for that.
  static const _nestedSelect =
      '*, supplier_groups:order_supplier_groups(*, items:order_items(*))';

  Future<List<Map<String, dynamic>>> _fetchOrders({String? clientId}) {
    var query = _client.from('orders').select(_nestedSelect);
    if (clientId != null) query = query.eq('client_id', clientId);
    return query.order('placed_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> watchOrdersForUser(String userId) {
    return withRealtimeRetry(
      () => _client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('client_id', userId)
          .asyncMap((_) => _fetchOrders(clientId: userId)),
    );
  }

  Stream<Map<String, dynamic>> watchOrderById(String orderId) {
    return withRealtimeRetry(
      () => _client
          .from('orders')
          .stream(primaryKey: ['id'])
          .eq('id', orderId)
          .asyncMap(
            (_) => _client.from('orders').select(_nestedSelect).eq('id', orderId).single(),
          ),
    );
  }

  /// RLS on `orders` (`orders_select_visible`) already only lets a
  /// supplier session see orders where they have a group at all — the
  /// refetch itself needs no extra filtering to scope its *results* to
  /// "my" orders. But the *trigger* for that refetch does: watching
  /// `orders` directly (no `supplier_id` column there) would mean any
  /// change to ANY order from ANY client re-runs this supplier's full
  /// nested fetch. Watching `order_supplier_groups` instead — which does
  /// have `supplier_id` — narrows that to only this supplier's own groups
  /// actually changing (a new order routed to them, one of their groups'
  /// status updated), while the refetch itself is unchanged.
  Stream<List<Map<String, dynamic>>> watchOrdersForSupplier(String supplierId) {
    return withRealtimeRetry(
      () => _client
          .from('order_supplier_groups')
          .stream(primaryKey: ['id'])
          .eq('supplier_id', supplierId)
          .asyncMap((_) => _fetchOrders()),
    );
  }

  Stream<List<Map<String, dynamic>>> watchAllOrders() {
    return withRealtimeRetry(
      () => _client
          .from('orders')
          .stream(primaryKey: ['id'])
          .asyncMap((_) => _fetchOrders()),
    );
  }

  Future<String> placeOrder(Map<String, dynamic> params) async {
    final id = await _client.rpc('place_order', params: params);
    return id as String;
  }

  Future<Map<String, dynamic>> fetchOrderById(String orderId) {
    return _client.from('orders').select(_nestedSelect).eq('id', orderId).single();
  }

  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required String status,
    String? cancellationReason,
    String? cancelledBy,
  }) {
    return _client.rpc(
      'update_order_group_status',
      params: {
        'p_order_id': orderId,
        'p_group_id': groupId,
        'p_status': status,
        'p_cancellation_reason': cancellationReason,
        'p_cancelled_by': cancelledBy,
      },
    );
  }

  /// Second step of attaching a supplier voice message — the RPC that
  /// records its already-uploaded path (see `attachSupplierVoiceMessage`,
  /// `SupabaseOrderRepository`, and `0008_lot9_order_voice_message.sql` for
  /// why this can't happen inside `placeOrder` itself).
  Future<void> setVoiceMessage({
    required String orderId,
    required String voicePath,
    required int durationSeconds,
  }) {
    return _client.rpc(
      'set_order_voice_message',
      params: {
        'p_order_id': orderId,
        'p_voice_path': voicePath,
        'p_duration_seconds': durationSeconds,
      },
    );
  }
}
