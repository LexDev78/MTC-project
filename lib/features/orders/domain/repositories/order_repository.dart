import '../entities/order.dart';
import '../entities/order_status.dart';

abstract interface class OrderRepository {
  Stream<List<Order>> watchOrdersForUser(String userId);

  Stream<Order> watchOrderById(String orderId);

  Future<Order> placeOrder({
    required String clientId,
    required List<CheckoutGroupInput> groups,
    required String deliveryAddressLabel,
    required String deliveryCity,
    required String deliveryDetails,
    required double deliveryLatitude,
    required double deliveryLongitude,
  });

  Future<void> updateGroupStatus({
    required String orderId,
    required String groupId,
    required OrderStatus status,
  });
}
