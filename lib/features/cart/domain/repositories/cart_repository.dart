import '../entities/cart_item.dart';

abstract interface class CartRepository {
  Stream<List<CartItem>> watchCart(String userId);

  /// Adds [quantity] units of a product; if that product is already in the
  /// user's cart, increments the existing line instead of duplicating it.
  Future<void> addItem({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    int quantity = 1,
  });

  Future<void> updateQuantity({
    required String userId,
    required String cartItemId,
    required int quantity,
  });

  Future<void> removeItem({required String userId, required String cartItemId});

  Future<void> clear(String userId);
}
