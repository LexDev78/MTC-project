import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

final _product = Product(
  id: 'product-test-001',
  supplierId: 'supplier-test',
  supplierName: 'Fournisseur Test',
  supplierType: SupplierType.tiers,
  name: 'Produit de test',
  description: 'Un produit pour le test du bouton panier rapide.',
  category: ProductCategory.textilesBogolan,
  priceFcfa: 5000,
  stockQuantity: 10,
  imageUrls: const [],
  city: 'Bamako',
  ratingAverage: 4.5,
  ratingCount: 10,
  allowsSelfDelivery: true,
  allowsMtcDelivery: true,
  weightKg: 1.0,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  testWidgets(
    'tapping the cart icon on a product card adds it to the cart without '
    'navigating away',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith(
            (ref) => Stream.value(
              AppUser.client(
                id: 'test-client',
                displayName: 'Testeur',
                usernameOrPhone: 'testeur',
                phoneNumber: '+22300000000',
                createdAt: DateTime(2024, 1, 1),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: ProductCard(product: _product)),
          ),
        ),
      );

      expect(find.text('Produit de test'), findsOneWidget);
      final cartsBefore = await container.read(cartItemsProvider.future);
      expect(cartsBefore, isEmpty);

      final scheme = Theme.of(
        tester.element(find.text('Produit de test')),
      ).colorScheme;
      Container buttonBackground() => tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.shopping_cart_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      Icon buttonIcon() =>
          tester.widget<Icon>(find.byIcon(Icons.shopping_cart_rounded));

      // Not in the cart yet — solid purple button, white icon, no border.
      expect(buttonIcon().color, scheme.onPrimary);
      expect((buttonBackground().decoration as BoxDecoration).border, isNull);

      await tester.tap(find.byIcon(Icons.shopping_cart_rounded));
      await tester.pump();

      // Confirmation shown, and we never navigated to a product-detail
      // route — the card itself is still the only thing on screen.
      expect(find.textContaining('ajouté au panier'), findsOneWidget);
      expect(find.text('Produit de test'), findsOneWidget);

      final cartsAfter = await container.read(cartItemsProvider.future);
      expect(cartsAfter, hasLength(1));
      expect(cartsAfter.single.productId, _product.id);
      expect(cartsAfter.single.quantity, 1);

      // Now that it's in the cart, the button flips to a white background
      // with a blue (primary) cart icon.
      expect(buttonIcon().color, scheme.primary);
      expect(
        (buttonBackground().decoration as BoxDecoration).border,
        isNotNull,
      );

      // Tapping it again removes it — not a second add.
      await tester.tap(find.byIcon(Icons.shopping_cart_rounded));
      await tester.pump();

      expect(find.textContaining('retiré du panier'), findsOneWidget);
      final cartsAfterRemoval = await container.read(cartItemsProvider.future);
      expect(cartsAfterRemoval, isEmpty);
      expect(buttonIcon().color, scheme.onPrimary);
      expect((buttonBackground().decoration as BoxDecoration).border, isNull);
    },
  );
}
