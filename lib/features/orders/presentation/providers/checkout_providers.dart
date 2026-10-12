import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/mock_data/malian_locations.dart';
import 'package:mtc_app/core/utils/geo_distance.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_pricing.dart';
import 'package:mtc_app/features/catalog/domain/promotion_pricing.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../data/mock_pickup_points.dart';
import '../../domain/delivery_pricing.dart';
import '../../domain/entities/fulfillment.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/payment.dart';

/// One supplier's checkout group as computed from the current cart — not a
/// domain entity, just a presentation-layer view model.
typedef CheckoutGroupView = ({
  String supplierId,
  String supplierName,
  String supplierCity,
  List<CartItem> items,
  bool allowsSelfDelivery,
  bool allowsMtcDelivery,
  Set<ProductCategory> categories,
  double totalWeightKg,
  int mtcDeliveryFeeFcfa,
  int subtotalFcfa,
});

/// Where MTC would be driving *to*, for the dynamic fee calculation below —
/// the home address for [FulfillmentMethod.homeDelivery], the chosen agency
/// for [FulfillmentMethod.pickupPoint]. `null` while nothing's picked yet.
({double latitude, double longitude})? _destination(Ref ref) {
  final method = ref.watch(fulfillmentMethodProvider);
  if (method == FulfillmentMethod.pickupPoint) {
    final point = ref.watch(selectedPickupPointProvider);
    if (point == null) return null;
    return (latitude: point.latitude, longitude: point.longitude);
  }
  final address = ref.watch(defaultAddressProvider);
  if (address == null) return null;
  return (latitude: address.latitude, longitude: address.longitude);
}

/// MTC's delivery fee for one supplier group — 1000-4000 FCFA depending on
/// distance to [destination], the group's cargo weight, and product
/// category (see `computeHomeDeliveryFeeFcfa`) — never a flat rate, and
/// never folded into any product's own price.
int _mtcDeliveryFeeFor({
  required String supplierCity,
  required ({double latitude, double longitude})? destination,
  required double totalWeightKg,
  required Set<ProductCategory> categories,
}) {
  final supplierCoordinates = MalianCity.values
      .firstWhere(
        (c) => c.label.toLowerCase() == supplierCity.toLowerCase(),
        orElse: () => MalianCity.bamako,
      )
      .coordinates;

  // No destination chosen yet (no address on file / no pickup point picked)
  // — estimate with a mid-bracket distance rather than showing 0 FCFA.
  final distanceKm = destination == null
      ? 15.0
      : GeoDistance.haversineKm(
          lat1: supplierCoordinates.latitude,
          lon1: supplierCoordinates.longitude,
          lat2: destination.latitude,
          lon2: destination.longitude,
        );

  return computeHomeDeliveryFeeFcfa(
    distanceKm: distanceKm,
    totalWeightKg: totalWeightKg,
    categories: categories,
  );
}

/// Set right before pushing to checkout from a single product's "Acheter"
/// (buy-now) button — `product_detail_screen.dart`, `favorite_line_item.dart`
/// — instead of adding it to the shared cart first. When set,
/// [checkoutGroupsProvider] builds its one group from this item alone, so
/// placing the order never touches (or clears) whatever else is already
/// sitting in the client's actual cart.
///
/// Deliberately **not** `autoDispose`: it's written via `ref.read(...).state
/// = ...` immediately followed by `context.push` from a widget that isn't
/// watching it, so there's no listener keeping it alive across that gap —
/// an `autoDispose` version can (and in practice does) get garbage
/// collected before the checkout screen's first build ever reads it,
/// silently falling back to the real cart and making "Acheter" look like it
/// just reopens "Mon panier". Every entry point into checkout sets this
/// explicitly instead — the single-item buy-now buttons set it to that
/// item, every cart-based entry point (`cart_screen.dart`,
/// `favorites_screen.dart`'s multi-select "Acheter") resets it to `null` —
/// so its value never depends on disposal timing either way.
final buyNowItemProvider = StateProvider<CartItem?>((ref) => null);

final checkoutGroupsProvider = FutureProvider<List<CheckoutGroupView>>((
  ref,
) async {
  final buyNowItem = ref.watch(buyNowItemProvider);
  final cartItems = buyNowItem != null
      ? [buyNowItem]
      : await ref.watch(cartItemsProvider.future);
  final destination = _destination(ref);

  // Une seule lecture pour tout le panier (`fetch_pricing_inputs`, `0068`),
  // là où cet écran appelait `getById` par article — une requête imbriquée
  // chacune, ramenant caractéristiques, options et variantes dont il n'a
  // aucun usage ici.
  final pricing = await ref
      .watch(productRepositoryProvider)
      .fetchPricing(cartItems.map((i) => i.productId).toSet().toList());

  final bySupplier = <String, List<CartItem>>{};
  for (final item in cartItems) {
    bySupplier.putIfAbsent(item.supplierId, () => []).add(item);
  }

  final groups = <CheckoutGroupView>[];
  for (final entry in bySupplier.entries) {
    // Un article dont le produit a disparu entre la mise au panier et le
    // paiement : on l'écarte du calcul plutôt que de faire échouer tout
    // l'écran.
    final lines = [
      for (final item in entry.value)
        if (pricing[item.productId] case final p?) (item: item, pricing: p),
    ];
    if (lines.isEmpty) continue;

    final allowsSelf = lines.every((l) => l.pricing.allowsSelfDelivery);
    final allowsMtc = lines.every((l) => l.pricing.allowsMtcDelivery);
    final categories = lines.map((l) => l.pricing.category).toSet();
    var totalWeightKg = 0.0;
    for (final line in lines) {
      totalWeightKg += line.pricing.weightKg * line.item.quantity;
    }
    // Mêmes remises qu'au panier, et surtout mêmes que celles que
    // `place_order` appliquera : le sous-total annoncé ici est celui qui
    // sera facturé, pas la somme des prix figés à la mise au panier.
    var subtotal = 0;
    for (final line in lines) {
      subtotal +=
          effectiveUnitPriceFcfa(
            basePriceFcfa: line.pricing.basePriceFor(line.item.variantId),
            promotions: line.pricing.promotions,
            quantity: line.item.quantity,
          ) *
          line.item.quantity;
    }
    final fee = allowsMtc
        ? _mtcDeliveryFeeFor(
            supplierCity: lines.first.pricing.city,
            destination: destination,
            totalWeightKg: totalWeightKg,
            categories: categories,
          )
        : 0;

    groups.add((
      supplierId: entry.key,
      supplierName: lines.first.pricing.supplierName,
      supplierCity: lines.first.pricing.city,
      items: [for (final line in lines) line.item],
      allowsSelfDelivery: allowsSelf,
      allowsMtcDelivery: allowsMtc,
      categories: categories,
      totalWeightKg: totalWeightKg,
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

/// Global, order-level "how does the client receive this order" choice —
/// separate from [deliveryModeChoiceProvider], which is per-supplier and
/// about *who* delivers. Defaults to home delivery so a client who never
/// touches this selector still gets today's behavior.
final fulfillmentMethodProvider = StateProvider<FulfillmentMethod>(
  (ref) => FulfillmentMethod.homeDelivery,
);

final pickupPointsProvider = Provider<List<PickupPoint>>(
  (ref) => mockPickupPoints,
);

/// `null` until the client actively picks one — [CheckoutController]
/// blocks `placeOrder()` on this being unset when the pickup-point method
/// is active, same as it already does for a missing home address.
final selectedPickupPointProvider = StateProvider<PickupPoint?>((ref) => null);

/// Pre-filled from the signed-in client's account phone (read once, not
/// watched, so a later edit here isn't clobbered if `currentUserProvider`
/// happens to re-emit) — still freely editable from there.
final courierPhoneProvider = StateProvider<String>((ref) {
  final user = ref.read(currentUserProvider).valueOrNull;
  return user is ClientUser ? user.phoneNumber : '';
});

/// Optional second contact number — `null` until the client taps "add
/// another number"; [HomeDeliveryForm] removes it by setting this back to
/// `null`.
final alternatePhoneProvider = StateProvider<String?>((ref) => null);

/// The client's note to the supplier — text or voice, mutually exclusive
/// (setting one via [CheckoutController]/the composer clears the other).
final supplierMessageTypeProvider = StateProvider<SupplierMessageType>(
  (ref) => SupplierMessageType.none,
);
final supplierMessageTextProvider = StateProvider<String>((ref) => '');
final supplierMessageVoicePathProvider = StateProvider<String?>((ref) => null);
final supplierMessageVoiceDurationProvider = StateProvider<int?>((ref) => null);

const priorityOrderFeeFcfa = 1000;

final isPriorityOrderProvider = StateProvider<bool>((ref) => false);

/// The next 3 days, offered as delivery-date choices for home delivery.
final deliveryDateOptionsProvider = Provider<List<DateTime>>((ref) {
  final today = DateTime.now();
  return List.generate(3, (i) {
    final date = today.add(Duration(days: i + 1));
    return DateTime(date.year, date.month, date.day);
  });
});

final selectedDeliveryDateProvider = StateProvider<DateTime>(
  (ref) => ref.watch(deliveryDateOptionsProvider).first,
);

const deliveryTimeSlotOptions = ['10:00 - 12:00', '12:00 - 15:00', '15:00 - 18:00'];

final selectedDeliveryTimeSlotProvider = StateProvider<String>(
  (ref) => deliveryTimeSlotOptions.first,
);

/// When the client pays — defaults to on-delivery so a client who never
/// touches this selector still gets today's (no-payment-step) behavior.
final paymentMethodProvider = StateProvider<PaymentMethod>(
  (ref) => PaymentMethod.onDelivery,
);

/// Set once the mocked Mobile Money sheet reports a successful payment for
/// [PaymentMethod.now] — `null` means "not paid yet", which
/// [CheckoutController] blocks `placeOrder()` on.
final mobileMoneyProviderChoiceProvider = StateProvider<MobileMoneyProvider?>(
  (ref) => null,
);
