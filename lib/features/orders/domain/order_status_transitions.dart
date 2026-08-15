import 'entities/order_status.dart';

/// The normal forward path a supplier group's status moves through.
/// `updateGroupStatus` had no such check before this — nothing prevented
/// e.g. a stray tap from moving a `delivered` group back to `pending`.
const List<OrderStatus> _forwardOrder = [
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.inTransit,
  OrderStatus.delivered,
];

/// Whether a supplier group may move from [from] to [to]: the single next
/// step along [_forwardOrder] — skipping intermediate steps is *not*
/// allowed, the supplier must confirm each stage in turn before moving to
/// the next — or a cancellation from any non-terminal status. Neither
/// `delivered` nor `cancelled` can transition anywhere else. Mirrored
/// server-side in `update_order_group_status`
/// (`supabase/migrations/0010_client_cancel_and_sequential_status.sql`).
bool isValidTransition(OrderStatus from, OrderStatus to) {
  if (from == to) return false;
  if (from == OrderStatus.delivered || from == OrderStatus.cancelled) {
    return false;
  }
  if (to == OrderStatus.cancelled) return true;

  final fromIndex = _forwardOrder.indexOf(from);
  final toIndex = _forwardOrder.indexOf(to);
  if (fromIndex == -1 || toIndex == -1) return false;
  return toIndex == fromIndex + 1;
}

/// Whether the client may cancel a supplier group themselves: only while
/// it's still `pending`, i.e. before the supplier has accepted it. Once
/// accepted, cancellation is the supplier's call alone (see
/// [isValidTransition]) — mirrored server-side in the same RPC.
bool canClientCancel(OrderStatus status) => status == OrderStatus.pending;
