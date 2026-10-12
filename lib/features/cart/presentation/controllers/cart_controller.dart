import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_variant.dart';

import '../providers/cart_providers.dart';

class CartController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// [variant] is `null` for a variant-less product, or when the caller
  /// (quick-add from the catalog grid, favorites "Acheter"/"Ajouter au
  /// panier") doesn't offer a picker — in that case, a product that
  /// `hasVariants` falls back to whichever one the supplier marked
  /// `isDefault`, so those flows keep working without forcing a detour
  /// through the product page. `product.variants` is only non-empty when
  /// [product] came from `getById` (its nested select) — every one of the
  /// no-picker call sites above already fetches through that path.
  Future<void> addProduct(Product product, {int quantity = 1, ProductVariant? variant}) async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return;

    final effectiveVariant =
        variant ??
        (product.hasVariants
            ? product.variants.firstWhereOrNull((v) => v.isDefault)
            : null);

    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref
          .read(cartRepositoryProvider)
          .addItem(
            userId: userId,
            productId: product.id,
            supplierId: product.supplierId,
            productName: product.name,
            unitPriceFcfa: effectiveVariant?.priceFcfa ?? product.priceFcfa,
            quantity: quantity,
            variantId: effectiveVariant?.id,
            variantName: effectiveVariant?.name,
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
