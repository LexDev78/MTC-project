import '../entities/cart_item.dart';

abstract interface class CartRepository {
  Stream<List<CartItem>> watchCart(String userId);

  /// Adds [quantity] units of a product; if that exact product+[variantId]
  /// combination is already in the user's cart, increments the existing
  /// line instead of duplicating it — two different variants of the same
  /// product never merge.
  Future<void> addItem({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    int quantity = 1,
    String? variantId,
    String? variantName,
  });

  Future<void> updateQuantity({
    required String userId,
    required String cartItemId,
    required int quantity,
  });

  Future<void> removeItem({required String userId, required String cartItemId});

  Future<void> clear(String userId);
}
