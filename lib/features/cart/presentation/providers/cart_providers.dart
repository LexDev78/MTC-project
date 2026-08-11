import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../data/datasources/in_memory_cart_datasource.dart';
import '../../data/repositories/in_memory_cart_repository.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';

final cartDatasourceProvider = Provider<InMemoryCartDatasource>((ref) {
  return InMemoryCartDatasource();
});

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return InMemoryCartRepository(ref.watch(cartDatasourceProvider));
});

final cartItemsProvider = StreamProvider<List<CartItem>>((ref) {
  final userId = ref.watch(currentUserProvider).valueOrNull?.id;
  if (userId == null) return Stream.value(const <CartItem>[]);
  return ref.watch(cartRepositoryProvider).watchCart(userId);
});

final cartTotalFcfaProvider = Provider<int>((ref) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  return items.fold(
    0,
    (sum, item) => sum + item.unitPriceFcfaSnapshot * item.quantity,
  );
});

final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartItemsProvider).valueOrNull ?? const <CartItem>[];
  return items.fold(0, (sum, item) => sum + item.quantity);
});
