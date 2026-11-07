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
import 'package:mtc_app/features/cart/presentation/screens/cart_screen.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';

import '../../support/shop_fixtures.dart';

/// Le panier du kit, sans base : un dépôt qui note les gestes du client.

final _produits = {for (final p in catalogueDemo()) p.id: p};

CartItem _ligne(String produit, int quantite) {
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
  );
}

class _Panier implements CartRepository {
  final gestes = <String>[];

  @override
  Future<void> updateQuantity({
    required String userId,
    required String cartItemId,
    required int quantity,
  }) async => gestes.add('$cartItemId=$quantity');

  @override
  Future<void> removeItem({
    required String userId,
    required String cartItemId,
  }) async => gestes.add('retirer $cartItemId');

  @override
  Future<void> clear(String userId) async => gestes.add('vider');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

late _Panier _panier;
late ProviderContainer _conteneur;

Future<void> _ouvrir(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 1600) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  _panier = _Panier();
  _conteneur = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWith((ref) => Stream.value(clientAwa())),
      cartItemsProvider.overrideWith(
        (ref) => Stream.value([_ligne('miel', 2), _ligne('radio', 1)]),
      ),
      cartRepositoryProvider.overrideWithValue(_panier),
      for (final p in _produits.values)
        productDetailProvider(p.id).overrideWith((ref) async => p),
      cartPricingProvider.overrideWith((ref) async => const {}),
      checkoutHasPromoCodeProvider.overrideWith((ref) async => false),
    ],
  );
  addTearDown(_conteneur.dispose);
  _conteneur.listen(currentUserProvider, (_, _) {});
  _conteneur.read(buyNowItemProvider.notifier).state = _ligne('masque', 1);

  final router = GoRouter(
    initialLocation: '/client/cart',
    routes: [
      GoRoute(
        path: '/client/cart',
        builder: (context, state) => const ShopScope(child: CartScreen()),
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (context, state) => const Scaffold(body: Text('PAIEMENT')),
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
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await tester.tap(cible);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// La ligne du panier qui porte [titre].
Finder _dans(String titre, Finder cible) => find.descendant(
  of: find.ancestor(
    of: find.text(titre),
    matching: find.byType(ShopProductListItem),
  ),
  matching: cible,
);

void main() {
  testWidgets('la quantité monte, descend, et la corbeille retire la ligne', (
    tester,
  ) async {
    await _ouvrir(tester);
    await _toucher(
      tester,
      _dans('Miel pur de Kita', find.byTooltip('Ajouter un')),
    );
    await _toucher(
      tester,
      _dans('Miel pur de Kita', find.byTooltip('Retirer un')),
    );
    await _toucher(
      tester,
      _dans('Radio FM solaire', find.byTooltip('Retirer du panier')),
    );
    expect(_panier.gestes, [
      'ligne-miel=3',
      'ligne-miel=1',
      'retirer ligne-radio',
    ]);
  });

  testWidgets('à une unité, on ne descend plus : on retire', (tester) async {
    await _ouvrir(tester);
    final moins = tester.widget<OutlinedButton>(
      find.descendant(
        of: _dans('Radio FM solaire', find.byTooltip('Retirer un')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(moins.onPressed, isNull);
  });

  testWidgets('vider demande confirmation', (tester) async {
    await _ouvrir(tester);
    await _toucher(tester, find.text('Vider'));
    expect(find.text('Vider le panier ?'), findsOneWidget);
    await _toucher(tester, find.text('Annuler'));
    expect(_panier.gestes, isEmpty);

    await _toucher(tester, find.text('Vider'));
    await _toucher(tester, find.widgetWithText(TextButton, 'Vider').last);
    expect(_panier.gestes, ['vider']);
  });

  testWidgets(
    '« Commander » part avec le panier, pas avec un achat immédiat oublié',
    (tester) async {
      await _ouvrir(tester);
      expect(_conteneur.read(buyNowItemProvider), isNotNull);
      await _toucher(tester, find.text('Commander'));
      expect(find.text('PAIEMENT'), findsOneWidget);
      expect(_conteneur.read(buyNowItemProvider), isNull);
    },
  );
}
