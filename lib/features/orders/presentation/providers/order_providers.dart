import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/in_memory_order_datasource.dart';
import '../../data/repositories/in_memory_order_repository.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

final orderDatasourceProvider = Provider<InMemoryOrderDatasource>((ref) {
  return InMemoryOrderDatasource();
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return InMemoryOrderRepository(ref.watch(orderDatasourceProvider));
});

final ordersForUserProvider = StreamProvider<List<Order>>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const <Order>[]);
  return ref.watch(orderRepositoryProvider).watchOrdersForUser(userId);
});

final orderDetailProvider = StreamProvider.family<Order, String>((
  ref,
  orderId,
) {
  return ref.watch(orderRepositoryProvider).watchOrderById(orderId);
});
