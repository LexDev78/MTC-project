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

/// Whether a supplier group may move from [from] to [to]: any forward step
/// along [_forwardOrder] (skipping intermediate steps is allowed — a
/// self-delivering supplier may jump straight from `pending` to
/// `inTransit`), or a cancellation from any non-terminal status. Neither
/// `delivered` nor `cancelled` can transition anywhere else.
bool isValidTransition(OrderStatus from, OrderStatus to) {
  if (from == to) return false;
  if (from == OrderStatus.delivered || from == OrderStatus.cancelled) {
    return false;
  }
  if (to == OrderStatus.cancelled) return true;

  final fromIndex = _forwardOrder.indexOf(from);
  final toIndex = _forwardOrder.indexOf(to);
  if (fromIndex == -1 || toIndex == -1) return false;
  return toIndex > fromIndex;
}
