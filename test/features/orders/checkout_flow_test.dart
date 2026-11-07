import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/theme/app_theme.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/domain/entities/cart_item.dart';
import 'package:mtc_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_pricing.dart';
import 'package:mtc_app/features/catalog/domain/repositories/product_repository.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/fulfillment.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/orders/domain/order_reference.dart';
import 'package:mtc_app/features/orders/domain/repositories/order_repository.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/orders/presentation/screens/checkout_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/order_success_screen.dart';
import 'package:mtc_app/features/orders/presentation/screens/payment_method_screen.dart';
import 'package:mtc_app/features/profile/domain/entities/address.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/promo_codes/domain/repositories/promo_code_repository.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';

import '../../support/shop_fixtures.dart';

/// Le paiement du kit, sans base : les vrais providers de la commande
/// (groupes, frais, contrôleur), sur des dépôts qui notent ce qu'on leur
/// demande.

final _produits = {for (final p in catalogueDemo()) p.id: p};

class _Produits implements ProductRepository {
  @override
  Future<Map<String, ProductPricing>> fetchPricing(List<String> ids) async => {
    for (final id in ids)
      if (_produits[id] case final p?)
        id: ProductPricing(
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
        ),
  };

  @override
  Future<Product> getById(String id) async => _produits[id]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CodesPromo implements PromoCodeRepository {
  @override
  Future<bool> existsForProducts(List<String> productIds) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Panier implements CartRepository {
  int vidages = 0;

  @override
  Future<void> clear(String userId) async => vidages++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// La commande passée, telle que `place_order` la rendrait ; les arguments
/// reçus sont gardés pour vérification.
class _Commandes implements OrderRepository {
  Map<Symbol, dynamic>? recus;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #placeOrder) {
      recus = invocation.namedArguments;
      return Future.value(_commande);
    }
    return super.noSuchMethod(invocation);
  }
}

final _commande = Order(
  id: '3f2a9c1b-5d7e-4c2a-9b1e-7a6d5c4b3a21',
  clientId: 'client-awa',
  clientDisplayNameSnapshot: 'Awa Traoré',
  supplierGroups: const [],
  status: OrderStatus.pending,
  placedAt: DateTime(2026, 10, 21, 9, 30),
  totalFcfa: 59750,
  deliveryCity: 'Bamako',
  clientContact: const OrderContact(
    phone: '+223 70 12 34 56',
    addressLabel: 'Maison',
    addressDetails: 'Badalabougou',
    latitude: 12.62,
    longitude: -7.98,
  ),
);

CartItem _ligne(String produit) {
  final p = _produits[produit]!;
  return CartItem(
    id: 'ligne-$produit',
    userId: 'client-awa',
    productId: produit,
    supplierId: p.supplierId,
    productNameSnapshot: p.name,
    unitPriceFcfaSnapshot: p.priceFcfa,
    quantity: 1,
    addedAt: DateTime(2026, 10, 20),
  );
}

const _adresse = Address(
  id: 'adr-1',
  userId: 'client-awa',
  label: 'Maison',
  city: 'Bamako',
  details: 'Rue 312, porte 18, Badalabougou',
  latitude: 12.6229,
  longitude: -7.9887,
);

late _Panier _panier;
late _Commandes _commandes;
late ProviderContainer _conteneur;

Future<void> _ouvrir(WidgetTester tester, {CartItem? achatImmediat}) async {
  // Assez haut pour que toute la revue soit construite : la liste ne bâtit
  // pas ce qui est sous le pli.
  tester.view.physicalSize = const Size(375, 2800) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _panier = _Panier();
  _commandes = _Commandes();
  _conteneur = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      cartItemsProvider.overrideWith(
        (ref) => Stream.value([_ligne('miel'), _ligne('panneau')]),
      ),
      productRepositoryProvider.overrideWithValue(_Produits()),
      promoCodeRepositoryProvider.overrideWithValue(_CodesPromo()),
      cartRepositoryProvider.overrideWithValue(_panier),
      orderRepositoryProvider.overrideWithValue(_commandes),
      addressesProvider.overrideWith((ref) => Stream.value([_adresse])),
      orderDetailProvider(
        _commande.id,
      ).overrideWith((ref) => Stream.value(_commande)),
    ],
  );
  addTearDown(_conteneur.dispose);
  _conteneur.listen(currentUserProvider, (_, _) {});
  if (achatImmediat != null) {
    _conteneur.read(buyNowItemProvider.notifier).state = achatImmediat;
  }

  final router = GoRouter(
    initialLocation: '/client/cart',
    routes: [
      GoRoute(
        path: '/client/cart',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/client/checkout'),
            child: const Text('VERS LE PAIEMENT'),
          ),
        ),
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) => const ShopScope(child: CheckoutScreen()),
        routes: [
          GoRoute(
            path: 'payment',
            builder: (context, state) =>
                const ShopScope(child: PaymentMethodScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/client/orders/:orderId/merci',
        builder: (context, state) => ShopScope(
          child: OrderSuccessScreen(orderId: state.pathParameters['orderId']!),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _conteneur,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _avancer(tester);
  await tester.tap(find.text('VERS LE PAIEMENT'));
  await _avancer(tester);
}

Future<void> _avancer(WidgetTester tester, {int pas = 6}) async {
  for (var i = 0; i < pas; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.ensureVisible(cible);
  await tester.pump();
  await tester.tap(cible);
  await _avancer(tester);
}

/// Le montant d'une ligne du récapitulatif.
String _valeur(WidgetTester tester, String libelle) => tester
    .widget<SummaryRow>(
      find.byWidgetPredicate((w) => w is SummaryRow && w.label == libelle),
    )
    .value;

void main() {
  testWidgets(
    'choisir la livraison MTC pour une boutique la facture au total',
    (tester) async {
      await _ouvrir(tester);
      expect(_valeur(tester, 'Livraison'), 'Gratuite');
      final avant = _valeur(tester, 'Total');

      await _toucher(tester, find.text('Coopérative de Kita'));
      await _toucher(tester, find.text('Livraison MTC'));

      final frais = _valeur(tester, 'Livraison');
      expect(frais, isNot('Gratuite'));
      // La ligne de la boutique annonce les mêmes frais que le total.
      expect(
        find.descendant(
          of: find.byType(ChevronListTile),
          matching: find.text(frais),
        ),
        findsOneWidget,
      );
      expect(_valeur(tester, 'Total'), isNot(avant));
    },
  );

  testWidgets(
    'payer avec Orange Money, commander, et arriver sur « Merci »',
    (tester) async {
      await _ouvrir(tester);
      await _toucher(tester, find.text('Mode de paiement'));
      await _toucher(tester, find.text('Orange Money'));
      await _toucher(tester, find.text('Confirmer'));

      expect(find.text('Orange Money'), findsOneWidget);
      await _toucher(tester, find.text('Payer et commander'));
      // La feuille s'ouvre sur l'opérateur choisi.
      expect(find.text('Mobile Money'), findsOneWidget);
      await _toucher(tester, find.text('Payer maintenant'));
      await _avancer(tester, pas: 14);
      await _toucher(tester, find.text('Continuer'));
      await _avancer(tester);

      final recus = _commandes.recus!;
      expect(recus[#paymentMethod], PaymentMethod.now);
      expect(recus[#mobileMoneyProvider], MobileMoneyProvider.orangeMoney);
      expect(recus[#fulfillmentMethod], FulfillmentMethod.homeDelivery);
      expect(recus[#deliveryAddressLabel], 'Maison');
      // Une commande du panier vide le panier.
      expect(_panier.vidages, 1);

      expect(find.text('Merci pour votre commande'), findsOneWidget);
      expect(find.text(_commande.reference), findsOneWidget);
    },
  );

  testWidgets(
    'au point de livraison, il faut en choisir un avant de commander',
    (tester) async {
      await _ouvrir(tester);
      await _toucher(tester, find.text('Point de livraison'));
      await _toucher(tester, find.text('Confirmer la commande'));
      expect(
        find.text('Choisissez un point de retrait avant de commander.'),
        findsWidgets,
      );
      expect(_commandes.recus, isNull);

      await _toucher(tester, find.text('Agence MTC — Hippodrome'));
      await _toucher(tester, find.text('Confirmer la commande'));
      expect(_commandes.recus![#fulfillmentMethod], FulfillmentMethod.pickupPoint);
      expect(
        _commandes.recus![#deliveryAddressLabel],
        'Agence MTC — Hippodrome',
      );
    },
  );

  testWidgets('quitter le paiement oublie l\'achat immédiat en attente', (
    tester,
  ) async {
    await _ouvrir(tester, achatImmediat: _ligne('masque'));
    expect(find.text('Masque dogon sculpté'), findsWidgets);
    expect(_conteneur.read(buyNowItemProvider), isNotNull);

    await tester.pageBack();
    await _avancer(tester);
    expect(find.text('VERS LE PAIEMENT'), findsOneWidget);
    expect(_conteneur.read(buyNowItemProvider), isNull);
  });
}
