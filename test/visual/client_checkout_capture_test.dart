import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_pricing.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/shop_product_data.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_success_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/payment_method_screen.dart';
import 'package:mtc_app/features/orders/presentation/widgets/mobile_money_payment_sheet.dart';
import 'package:mtc_app/features/profile/domain/entities/address.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../support/shop_capture.dart';
import '../support/shop_fixtures.dart';

final _produits = {for (final p in catalogueDemo()) p.id: p};

CartItem _ligne(String produit, int quantite, {String? variante}) {
  final p = _produits[produit]!;
  return CartItem(
    id: 'ligne-$produit',
    userId: 'client-awa',
    productId: produit,
    supplierId: p.supplierId,
    productNameSnapshot: p.name,
    unitPriceFcfaSnapshot: p.priceFcfa,
    quantity: quantite,
    addedAt: DateTime(2026, 10, 20),
    variantNameSnapshot: variante,
  );
}

final _panier = [
  _ligne('bogolan', 2, variante: 'Indigo 2 m'),
  _ligne('miel', 1),
  _ligne('panneau', 1),
];

ProductPricing _tarif(Product p) => ProductPricing(
  priceFcfa: p.priceFcfa,
  stockQuantity: p.stockQuantity,
  weightKg: p.weightKg,
  category: p.category,
  city: p.city,
  supplierId: p.supplierId,
  supplierName: p.supplierName,
  allowsSelfDelivery: p.allowsSelfDelivery,
  allowsMtcDelivery: p.allowsMtcDelivery,
  promotions: p.promotions,
);

const _adresse = Address(
  id: 'adr-1',
  userId: 'client-awa',
  label: 'Maison',
  city: 'Bamako',
  details: 'Rue 312, porte 18, Badalabougou',
  latitude: 12.6229,
  longitude: -7.9887,
);

List<CheckoutGroupView> _groupes() {
  final parBoutique = <String, List<CartItem>>{};
  for (final l in _panier) {
    parBoutique.putIfAbsent(l.supplierId, () => []).add(l);
  }
  return [
    for (final MapEntry(key: id, value: lignes) in parBoutique.entries)
      (
        supplierId: id,
        supplierName: _produits[lignes.first.productId]!.supplierName,
        supplierCity: 'Bamako',
        items: lignes,
        allowsSelfDelivery: true,
        allowsMtcDelivery: true,
        categories: {_produits[lignes.first.productId]!.category},
        totalWeightKg: 1,
        mtcDeliveryFeeFcfa: 1500,
        subtotalFcfa: lignes.fold(
          0,
          (s, l) =>
              s +
              _produits[l.productId]!
                      .unitPricing(quantity: l.quantity)
                      .priceFcfa *
                  l.quantity,
        ),
        promoDiscountFcfa: 0,
      ),
  ];
}

List<Override> _donnees() => [
  cartItemsProvider.overrideWith((ref) => Stream.value(_panier)),
  cartPricingProvider.overrideWith(
    (ref) async => {for (final p in _produits.values) p.id: _tarif(p)},
  ),
  for (final p in _produits.values)
    productDetailProvider(p.id).overrideWith((ref) async => p),
  addressesProvider.overrideWith((ref) => Stream.value([_adresse])),
  checkoutHasPromoCodeProvider.overrideWith((ref) async => true),
  checkoutGroupsProvider.overrideWith((ref) async => _groupes()),
];

final _commande = Order(
  id: '3f2a9c1b-5d7e-4c2a-9b1e-7a6d5c4b3a21',
  clientId: 'client-awa',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierGroups: const [],
  status: OrderStatus.pending,
  placedAt: DateTime(2026, 10, 21, 9, 30),
  totalFcfa: 92750,
  deliveryCity: 'Bamako',
  clientContact: const OrderContact(
    phone: '+223 70 12 34 56',
    addressLabel: 'Maison',
    addressDetails: 'Rue 312, porte 18, Badalabougou',
    latitude: 12.62,
    longitude: -7.98,
  ),
);

Future<void> _toucher(WidgetTester tester, String texte) async {
  await tester.tap(find.text(texte).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  capturerEcran(
    'panier',
    () => const CartScreen(),
    overrides: _donnees,
    hauteur: 1300,
  );
  capturerEcran(
    'paiement_revue',
    () => const CheckoutScreen(),
    overrides: _donnees,
    hauteur: 2300,
  );
  capturerEcran(
    'paiement_point_relais',
    () => const CheckoutScreen(),
    overrides: () => [
      ..._donnees(),
      fulfillmentMethodProvider.overrideWith(
        (ref) => FulfillmentMethod.pickupPoint,
      ),
    ],
    hauteur: 1500,
  );
  capturerEcran('mode_paiement_livraison', () => const PaymentMethodScreen());
  capturerEcran(
    'mode_paiement_orange',
    () => const PaymentMethodScreen(),
    geste: (tester) => _toucher(tester, 'Orange Money'),
  );
  capturerEcran(
    'commande_merci',
    () => const OrderSuccessScreen(orderId: 'cmd'),
    overrides: () => [
      orderDetailProvider('cmd').overrideWith((ref) => Stream.value(_commande)),
    ],
  );
  capturerEcran(
    'panier_vide',
    () => const CartScreen(),
    overrides: () => [
      cartItemsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
  );
  // La feuille Mobile Money, ouverte comme au paiement.
  capturerEcran(
    'paiement_mobile_money',
    () => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                showMobileMoneyPaymentSheet(context, amountFcfa: 92750),
            child: const Text('OUVRIR'),
          ),
        ),
      ),
    ),
    geste: (tester) => _toucher(tester, 'OUVRIR'),
  );
}
