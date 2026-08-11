import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../providers/checkout_providers.dart';
import '../providers/order_providers.dart';

class CheckoutController extends AsyncNotifier<Order?> {
  @override
  Future<Order?> build() async => null;

  Future<bool> placeOrder() async {
    final userId = ref.read(currentUserProvider).valueOrNull?.id;
    if (userId == null) return false;

    final address = ref.read(defaultAddressProvider);
    if (address == null) {
      state = AsyncError(
        const ValidationException(
          'Ajoutez une adresse de livraison avant de commander.',
        ),
        StackTrace.current,
      );
      return false;
    }

    final groups = await ref.read(checkoutGroupsProvider.future);
    if (groups.isEmpty) return false;

    final inputs = groups.map((g) {
      final mode =
          ref.read(deliveryModeChoiceProvider(g.supplierId)) ??
          (g.allowsSelfDelivery
              ? DeliveryMode.selfDelivery
              : DeliveryMode.mtcDelivery);
      return CheckoutGroupInput(
        supplierId: g.supplierId,
        supplierName: g.supplierName,
        items: g.items
            .map(
              (i) => OrderItem(
                productId: i.productId,
                productNameSnapshot: i.productNameSnapshot,
                unitPriceFcfaSnapshot: i.unitPriceFcfaSnapshot,
                quantity: i.quantity,
              ),
            )
            .toList(),
        deliveryMode: mode,
        mtcDeliveryFeeFcfa: g.mtcDeliveryFeeFcfa,
      );
    }).toList();

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final order = await ref
          .read(orderRepositoryProvider)
          .placeOrder(
            clientId: userId,
            groups: inputs,
            deliveryAddressLabel: address.label,
            deliveryCity: address.city,
            deliveryDetails: address.details,
            deliveryLatitude: address.latitude,
            deliveryLongitude: address.longitude,
          );
      await ref.read(cartRepositoryProvider).clear(userId);
      return order;
    });

    return !state.hasError;
  }
}

final checkoutControllerProvider =
    AsyncNotifierProvider<CheckoutController, Order?>(CheckoutController.new);
