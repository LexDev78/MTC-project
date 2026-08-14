library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart';

import '../../../test/support/supabase_test_harness.dart';

// A cart_item row FK-references both `products` and `suppliers`, so this
// must mirror a real seeded product (`product-001`, Bogolan Bamako) rather
// than a fabricated one — see the same constraint on `_userId` below.
final _product = Product(
  id: 'product-001',
  supplierId: DemoIds.supplierBogolanBamako,
  supplierName: 'Bogolan Bamako',
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  testWidgets(
    'tapping the cart icon on a product card adds it to the cart without '
    'navigating away',
    (tester) async {
      // cart_items RLS only grants `authenticated`, not `anon` — a fake
      // `currentUserProvider` override (as other widget-only tests use)
      // isn't enough here since the underlying Postgrest calls still go
      // out unauthenticated. Sign in for real as the seeded client1
      // account instead, and let currentUserProvider hydrate naturally.
      final supabaseClient = createTestSupabaseClient();
      await supabaseClient.auth.signInWithPassword(
        email: pseudoEmail('client1'),
        password: 'password123',
      );

      final container = ProviderContainer(
        overrides: [
          supabaseClientProvider.overrideWithValue(supabaseClient),
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

      // cartItemsProvider derives its userId from currentUserProvider and
      // falls back to an empty stream while that's still null — so reading
      // cartItemsProvider.future alone can spuriously resolve to `[]` via
      // that null-userId branch, before the real signed-in session has
      // hydrated. Wait for the real user explicitly first, or the later
      // "add to cart" tap can silently no-op against a still-null userId.
      final signedInUser = await container.read(currentUserProvider.future);
      expect(signedInUser, isA<AppUser>());

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
      // route — the card itself is still the only thing on screen. Its
      // own SnackBar only stays up 1s, so this check has to happen before
      // waiting out the (longer) Realtime round-trip below.
      expect(find.textContaining('ajouté au panier'), findsOneWidget);
      expect(find.text('Produit de test'), findsOneWidget);

      // cartItemsProvider is backed by a real Postgres Realtime stream
      // (write -> broadcast -> refetch) with no spinner shown while it
      // reconnects, so nothing keeps pumpAndSettle's frame-scheduler-based
      // loop waiting — a raw timed pump is the only way to reliably wait
      // out the round-trip here.
      await tester.pump(const Duration(seconds: 2));

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

      // Tapping it again removes it — not a second add. The tap's
      // onTap handler calls `hideCurrentSnackBar()` before showing the
      // new one — unlike the first tap (nothing to hide), this handoff
      // needs a beat of real time to land, so a zero-duration pump can
      // miss the new SnackBar's text.
      await tester.tap(find.byIcon(Icons.shopping_cart_rounded));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('retiré du panier'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      final cartsAfterRemoval = await container.read(cartItemsProvider.future);
      expect(cartsAfterRemoval, isEmpty);
      expect(buttonIcon().color, scheme.onPrimary);
      expect((buttonBackground().decoration as BoxDecoration).border, isNull);
    },
  );
}
