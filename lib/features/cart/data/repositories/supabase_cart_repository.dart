import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/supabase_cart_datasource.dart';

class SupabaseCartRepository implements CartRepository {
  SupabaseCartRepository(this._datasource);

  final SupabaseCartDatasource _datasource;

  @override
  Stream<List<CartItem>> watchCart(String userId) {
    return _datasource
        .watchForUser(userId)
        .map((rows) => rows.map(CartItem.fromJson).toList());
  }

  @override
  Future<void> addItem({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    int quantity = 1,
  }) {
    return _datasource.addOrIncrement(
      userId: userId,
      productId: productId,
      supplierId: supplierId,
      productName: productName,
      unitPriceFcfa: unitPriceFcfa,
      quantity: quantity,
    );
  }

  @override
  Future<void> updateQuantity({
    required String userId,
    required String cartItemId,
    required int quantity,
  }) {
    return _datasource.updateQuantity(cartItemId: cartItemId, quantity: quantity);
  }

  @override
  Future<void> removeItem({required String userId, required String cartItemId}) {
    return _datasource.removeItem(cartItemId);
  }

  @override
  Future<void> clear(String userId) => _datasource.clear(userId);
}
