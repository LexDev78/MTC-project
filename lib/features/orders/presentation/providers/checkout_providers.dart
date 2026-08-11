import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';

import '../../domain/entities/order_status.dart';

/// One supplier's checkout group as computed from the current cart — not a
/// domain entity, just a presentation-layer view model.
typedef CheckoutGroupView = ({
  String supplierId,
  String supplierName,
  List<CartItem> items,
  bool allowsSelfDelivery,
  bool allowsMtcDelivery,
  int mtcDeliveryFeeFcfa,
  int subtotalFcfa,
});

final checkoutGroupsProvider = FutureProvider<List<CheckoutGroupView>>((
  ref,
) async {
  final cartItems = await ref.watch(cartItemsProvider.future);
  final productRepository = ref.watch(productRepositoryProvider);

  final bySupplier = <String, List<CartItem>>{};
  for (final item in cartItems) {
    bySupplier.putIfAbsent(item.supplierId, () => []).add(item);
  }

  final groups = <CheckoutGroupView>[];
  for (final entry in bySupplier.entries) {
    final products = await Future.wait(
      entry.value.map((i) => productRepository.getById(i.productId)),
    );
    final allowsSelf = products.every((p) => p.allowsSelfDelivery);
    final allowsMtc = products.every((p) => p.allowsMtcDelivery);
    final fee = products.fold<int>(0, (max, p) {
      final productFee = p.mtcDeliveryFeeFcfa ?? 0;
      return productFee > max ? productFee : max;
    });
    final subtotal = entry.value.fold<int>(
      0,
      (sum, i) => sum + i.unitPriceFcfaSnapshot * i.quantity,
    );

    groups.add((
      supplierId: entry.key,
      supplierName: products.first.supplierName,
      items: entry.value,
      allowsSelfDelivery: allowsSelf,
      allowsMtcDelivery: allowsMtc,
      mtcDeliveryFeeFcfa: fee,
      subtotalFcfa: subtotal,
    ));
  }
  return groups;
});

/// User's explicit delivery-mode choice per supplier group; `null` means
/// "not chosen yet", in which case the UI falls back to that group's
/// cheapest available default (self-delivery when offered).
final deliveryModeChoiceProvider = StateProvider.family<DeliveryMode?, String>((
  ref,
  supplierId,
) {
  return null;
});
