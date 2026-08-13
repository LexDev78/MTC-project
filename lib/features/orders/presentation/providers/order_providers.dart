import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/supabase_order_datasource.dart';
import '../../data/repositories/supabase_order_repository.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/order_repository.dart';

final orderDatasourceProvider = Provider<SupabaseOrderDatasource>((ref) {
  return SupabaseOrderDatasource(ref.watch(supabaseClientProvider));
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return SupabaseOrderRepository(ref.watch(orderDatasourceProvider));
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

/// Every order, unfiltered — admin only, feeds the "fournisseur principal"
/// finance screen's platform-wide commission total (see
/// `platformCommissionSummaryProvider`).
final allOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(orderRepositoryProvider).watchAllOrders();
});
