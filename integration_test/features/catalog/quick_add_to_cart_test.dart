library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';

import '../../../test/support/supabase_test_harness.dart';

/// Attend qu'un contenu soit là (réseau réel), sans parier sur un délai.
Future<void> _attendre(WidgetTester tester, Finder cible) async {
  for (var i = 0; i < 40 && cible.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _toucher(WidgetTester tester, Finder cible) async {
  await _attendre(tester, cible);
  await tester.ensureVisible(cible.last);
  await tester.pump();
  await tester.tap(cible.last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await resetAndSeed();
  });

  // La carte produit du kit n'a plus de bouton panier : on ajoute depuis la
  // fiche, par « Acheter » puis la feuille d'achat. Ce test garde ce que
  // l'ancien vérifiait contre la vraie base — l'écriture du panier sous une
  // vraie session (la RLS de `cart_items` ne connaît que `authenticated`).
  testWidgets(
    'la feuille d\'achat met l\'article au panier, sans quitter la fiche',
    (tester) async {
      final supabaseClient = createTestSupabaseClient();
      await supabaseClient.auth.signInWithPassword(
        email: pseudoEmail('client1'),
        password: 'password123',
      );

      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(supabaseClient)],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: '/client/product/${DemoIds.product001}',
        routes: [
          GoRoute(
            path: '/client/product/:productId',
            builder: (context, state) => ShopScope(
              child: ProductDetailScreen(
                productId: state.pathParameters['productId']!,
              ),
            ),
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
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // `cartItemsProvider` tire son utilisateur de `currentUserProvider` et
      // rend une liste vide tant qu'il est nul : attendre la vraie session,
      // sinon l'ajout partirait sans utilisateur.
      final client = await container.read(currentUserProvider.future);
      expect(client, isA<AppUser>());
      expect(await container.read(cartItemsProvider.future), isEmpty);

      await _attendre(tester, find.text('Tissu Bogolan traditionnel'));
      expect(find.text('Tissu Bogolan traditionnel'), findsWidgets);

      await _toucher(tester, find.text('Acheter'));
      await _toucher(tester, find.text('Ajouter au panier'));

      expect(find.text('Ajouté au panier'), findsOneWidget);
      // Toujours sur la fiche : la confirmation n'emmène nulle part.
      expect(find.text('PAIEMENT'), findsNothing);

      // Le panier est un flux temps réel (écriture → diffusion → relecture)
      // sans indicateur pendant la reconnexion : un délai réel est la seule
      // attente fiable.
      await tester.pump(const Duration(seconds: 2));
      final panier = await container.read(cartItemsProvider.future);
      expect(panier, hasLength(1));
      expect(panier.single.productId, DemoIds.product001);
      expect(panier.single.quantity, 1);
    },
  );
}
