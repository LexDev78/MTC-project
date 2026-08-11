import 'dart:async';

import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/cart_item.dart';

class InMemoryCartDatasource {
  InMemoryCartDatasource() {
    // Pre-seed demo client2's cart so the checkout flow is reachable
    // immediately without needing to browse first.
    final now = DateTime.now();
    _items.addAll([
      CartItem(
        id: IdGenerator.next(),
        userId: DemoIds.clientMoussa,
        productId: 'product-015',
        supplierId: DemoIds.supplierAlimentationSegou,
        productNameSnapshot: 'Riz local 25kg',
        unitPriceFcfaSnapshot: 12500,
        quantity: 2,
        addedAt: now,
      ),
      CartItem(
        id: IdGenerator.next(),
        userId: DemoIds.clientMoussa,
        productId: 'product-011',
        supplierId: DemoIds.supplierElectroBamako,
        productNameSnapshot: 'Smartphone Android 64GB',
        unitPriceFcfaSnapshot: 85000,
        quantity: 1,
        addedAt: now,
      ),
    ]);
  }

  final List<CartItem> _items = [];
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<CartItem>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<CartItem>.unmodifiable(_items));
  }

  void addOrIncrement({
    required String userId,
    required String productId,
    required String supplierId,
    required String productName,
    required int unitPriceFcfa,
    required int quantity,
  }) {
    final existingIndex = _items.indexWhere(
      (i) => i.userId == userId && i.productId == productId,
    );
    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      _items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      _items.add(
        CartItem(
          id: IdGenerator.next(),
          userId: userId,
          productId: productId,
          supplierId: supplierId,
          productNameSnapshot: productName,
          unitPriceFcfaSnapshot: unitPriceFcfa,
          quantity: quantity,
          addedAt: DateTime.now(),
        ),
      );
    }
    _changesController.add(null);
  }

  void updateQuantity({required String cartItemId, required int quantity}) {
    final index = _items.indexWhere((i) => i.id == cartItemId);
    if (index == -1) return;
    _items[index] = _items[index].copyWith(quantity: quantity);
    _changesController.add(null);
  }

  void removeItem(String cartItemId) {
    _items.removeWhere((i) => i.id == cartItemId);
    _changesController.add(null);
  }

  void clear(String userId) {
    _items.removeWhere((i) => i.userId == userId);
    _changesController.add(null);
  }
}
