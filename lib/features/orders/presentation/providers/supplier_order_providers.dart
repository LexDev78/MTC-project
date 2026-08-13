import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import 'order_providers.dart';

/// One order, scoped to a single supplier — the projection
/// `SupplierOrderListScreen`/`SupplierOrderDetailScreen` actually read,
/// instead of the raw `Order`. A multi-supplier order's other groups (their
/// items, prices, status) are never exposed through this type, even though
/// `OrderRepository.watchOrdersForSupplier` returns the full `Order` under
/// the hood — this typedef is the privacy boundary between them.
typedef SupplierOrderView = ({
  String orderId,
  DateTime placedAt,
  String clientDisplayNameSnapshot,
  String clientPhoneSnapshot,
  String clientId,
  String deliveryAddressLabel,
  String deliveryCity,
  String deliveryDetails,
  OrderSupplierGroup myGroup,
});

SupplierOrderView _toView(Order order, String supplierId) {
  return (
    orderId: order.id,
    placedAt: order.placedAt,
    clientDisplayNameSnapshot: order.clientDisplayNameSnapshot,
    clientPhoneSnapshot: order.clientPhoneSnapshot,
    clientId: order.clientId,
    deliveryAddressLabel: order.deliveryAddressLabel,
    deliveryCity: order.deliveryCity,
    deliveryDetails: order.deliveryDetails,
    myGroup: order.supplierGroups.firstWhere((g) => g.supplierId == supplierId),
  );
}

final supplierOrdersProvider =
    StreamProvider.family<List<SupplierOrderView>, String>((ref, supplierId) {
      return ref
          .watch(orderRepositoryProvider)
          .watchOrdersForSupplier(supplierId)
          .map((orders) => orders.map((o) => _toView(o, supplierId)).toList());
    });

final supplierOrderDetailProvider =
    StreamProvider.family<SupplierOrderView, ({String orderId, String supplierId})>((
      ref,
      args,
    ) {
      return ref
          .watch(orderRepositoryProvider)
          .watchOrderById(args.orderId)
          .map((order) => _toView(order, args.supplierId));
    });

/// `null` means "every status" — the default view.
final myOrdersStatusFilterProvider = StateProvider.family<OrderStatus?, String>(
  (ref, supplierId) => null,
);
