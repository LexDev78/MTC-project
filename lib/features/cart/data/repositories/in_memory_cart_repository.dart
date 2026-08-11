import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/in_memory_cart_datasource.dart';

class InMemoryCartRepository implements CartRepository {
  InMemoryCartRepository(this._datasource);

  final InMemoryCartDatasource _datasource;

  @override
  Stream<List<CartItem>> watchCart(String userId) {
    return _datasource.watchAll().map(
      (items) => items.where((i) => i.userId == userId).toList(),
    );
  }

  @override
  Future<void> addItem({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    int quantity = 1,
  }) async {
    _datasource.addOrIncrement(
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
  }) async {
    _datasource.updateQuantity(cartItemId: cartItemId, quantity: quantity);
  }

  @override
  Future<void> removeItem({
    required String userId,
    required String cartItemId,
  }) async {
    _datasource.removeItem(cartItemId);
  }

  @override
  Future<void> clear(String userId) async => _datasource.clear(userId);
}
