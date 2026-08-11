import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';

import '../providers/cart_providers.dart';

class CartController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addProduct(Product product, {int quantity = 1}) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(cartRepositoryProvider)
          .addItem(
            userId: userId,
            productId: product.id,
            supplierId: product.supplierId,
            productName: product.name,
            unitPriceFcfa: product.priceFcfa,
            quantity: quantity,
          );
    });
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;

    if (quantity <= 0) {
      await removeItem(cartItemId);
      return;
    }

    await ref
        .read(cartRepositoryProvider)
        .updateQuantity(
          userId: userId,
          cartItemId: cartItemId,
          quantity: quantity,
        );
  }

  Future<void> removeItem(String cartItemId) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref
        .read(cartRepositoryProvider)
        .removeItem(userId: userId, cartItemId: cartItemId);
  }

  Future<void> clearCart() async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;
    await ref.read(cartRepositoryProvider).clear(userId);
  }
}

final cartControllerProvider = AsyncNotifierProvider<CartController, void>(
  CartController.new,
);
