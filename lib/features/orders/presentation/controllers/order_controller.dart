import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order_status.dart';
import '../providers/order_providers.dart';

/// Drives client-initiated order actions — currently just self-service
/// cancellation. Mirrors `SupplierOrderController.cancel`, but scoped to
/// what a client may do to their own order (see `canClientCancel`).
class OrderController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Cancels one supplier group of the client's own order. Only valid
  /// while that group is still `pending` — enforced both here (via the
  /// UI only offering it then) and server-side in
  /// `update_order_group_status`, which rejects it otherwise.
  Future<bool> cancel({
    required String orderId,
    required String groupId,
    String? reason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(orderRepositoryProvider)
          .updateGroupStatus(
            orderId: orderId,
            groupId: groupId,
            status: OrderStatus.cancelled,
            cancellationReason: reason,
            cancelledBy: CancelledBy.client,
          ),
    );
    return !state.hasError;
  }
}

final orderControllerProvider = AsyncNotifierProvider<OrderController, void>(
  OrderController.new,
);
