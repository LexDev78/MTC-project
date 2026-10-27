@Tags(['integration'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/supplier_product_form_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../support/supabase_test_harness.dart';

// Regression test for a real data-loss bug: `SupplierProductFormScreen` used
// to seed `VariantManagerPanel` directly from whatever `Product` it was
// pushed with — fine coming from `getById` (which embeds
// characteristics/variants), but the supplier's product list navigates here
// with the object from `watchMyProducts`, which does NOT embed them (only
// the scalar aggregate columns). Reopening the edit screen after leaving it
// therefore showed an empty variant list, and saving a new variant from that
// empty seed wiped every previously-saved one via
// `saveCharacteristicsAndVariants`'s full delete-then-insert. The fix makes
// this screen always `getById`-refetch the product on entry before it will
// render the panel at all. See `settle`/trap comments in
// `supplier_variant_manager_screen_test.dart` for why this file avoids
// `pumpAndSettle()` and wraps Supabase calls in `tester.runAsync()`.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

void main() {
  late ProviderContainer container;
  late SupabaseClient client;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    client = createTestSupabaseClient();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
  });

  // A fresh product created here rather than one of the seeded catalog
  // products: every seeded product now comes with a pre-existing "Taille :
  // Standard" default variant of its own
  // (`0021_backfill_default_variants_and_require_variant.sql`), which this
  // screen loads on entry — every variant-count assertion below assumes
  // starting from zero.
  Future<Product> loginAndFetchProduct(WidgetTester tester) {
    return tester.runAsync(() async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      final user = container.read(currentUserProvider).value! as SupplierTiersUser;
      final supplierId = container.read(operatingSupplierIdProvider)!;
      final supplierProfile = await container
          .read(supplierRepositoryProvider)
          .getById(supplierId);
      return container.read(productRepositoryProvider).createProduct(
        supplierId: supplierId,
        supplierName: supplierProfile.businessName,
        supplierType: SupplierType.tiers,
        isSupplierVerified: user.verificationStatus == VerificationStatus.verified,
        name: 'Produit test formulaire variantes',
        description: 'Produit créé pour tester le formulaire de variantes.',
        category: ProductCategory.autre,
        priceFcfa: 15000,
        stockQuantity: 60,
        weightKg: 1.0,
        city: 'Bamako',
        imageUrls: const [],
        allowsSelfDelivery: true,
        allowsMtcDelivery: true,
        sizes: const [],
        colors: const [],
        region: ProductRegion.mali,
      );
    }).then((p) => p!);
  }

  Future<void> prepareSurface(WidgetTester tester) async {
    // Taller than the sibling `supplier_variant_manager_screen_test.dart`'s
    // surface: this form has every product field (name, price, weight…)
    // above the variant panel, on top of the variant list growing as the
    // test adds more — 3000 stopped being enough once a saved variant tile
    // was already on screen for the "add a second variant" phase below.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> addField(
    WidgetTester tester, {
    required String typeLabel,
    required String value,
  }) async {
    await tester.tap(find.text('Ajouter un champ'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
    await settle(tester);
    await tester.tap(find.text(typeLabel).last);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('add-field-value-input')), value);
    await settle(tester);
    await tester.tap(find.text('Ajouter').last);
    await settle(tester);
  }

  testWidgets(
    'a variant saved inline survives leaving and re-entering the product '
    'sheet, and adding a second one keeps the first instead of erasing it',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);
      expect(product.hasVariants, isFalse);

      // A real `Navigator` with something underneath `SupplierProductFormScreen`
      // to pop back to — matches how the real app reaches this screen
      // (`context.push(AppRoutes.supplierTiersProductForm, ...)` from the
      // product list) now that its single "Enregistrer" button pops on
      // success (see `_submit`). Pushing a second instance below for the
      // "leaving and re-entering" step, rather than a second top-level
      // `tester.pumpWidget`, also sidesteps a `flutter_test` quirk where a
      // widget from an interleaved-`runAsync` second `pumpWidget` call
      // reports a real size/position that never actually hit-tests.
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await settle(tester);

      // ---- open the sheet, add the first variant, save --------------------
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Couleur', value: 'Rouge');
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (1)'), findsOneWidget);

      // The single "Enregistrer" button saves the product's own fields and
      // the characteristics/variants draft together, then pops back to the
      // dummy home above — no separate "Caractéristiques enregistrées."
      // snackbar/stay-on-screen step anymore (see `_submit`).
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      // ---- simulate leaving the sheet and coming back via the product ------
      // list: that list's `Product` objects never embed
      // characteristics/variants (see the file-level comment above), only
      // the scalar aggregate columns — reproduced here with `copyWith`.
      final listShapedProduct = (await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      ))!.copyWith(characteristics: const [], variants: const []);
      expect(listShapedProduct.hasVariants, isTrue);
      expect(listShapedProduct.variants, isEmpty);

      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => SupplierProductFormScreen(product: listShapedProduct),
          ),
        ),
      );
      await settle(tester);

      // The bug: this used to show no variants at all right here.
      expect(find.text('Variantes (1)'), findsOneWidget);
      expect(find.text('Rouge'), findsOneWidget);

      // ---- add a second variant and save ------------------------------------
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Taille', value: 'M');
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (2)'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      // The bug: this used to come back with just the "M" variant, the
      // earlier "Rouge" one erased by the full-replace save.
      expect(saved!.variants, hasLength(2));
      expect(saved.variants.map((v) => v.name).toSet(), {'Rouge', 'M'});

      await tester.runAsync(client.dispose);
    },
  );

  // Le prix d'une variante est figé à sa validation :
  //     prix = prix de base du produit + suppléments de ses propres options.
  // Encore faut-il que « prix de base » en soit un. Dès qu'une variante
  // existe, `products.price_fcfa` devient le **minimum** des prix de
  // variantes (trigger `product_variants_aggregate_products`,
  // `0018_product_variants.sql`) : s'il sert de base, une variante composée
  // plus tard hérite du supplément d'une autre, et son prix ne reflète plus
  // ses propres propriétés. C'est ce que ce test verrouille.
  testWidgets(
    'a variant composed after reopening the sheet is priced from the '
    "product's base price, not from another variant's surcharge",
    (tester) async {
      await prepareSurface(tester);
      // Créé à 15000, sans variante.
      final product = await loginAndFetchProduct(tester);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await settle(tester);

      // ---- première session : une seule variante, avec supplément --------
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'Rouge');
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-extra-cost-checkbox')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-delta-input')), '2000');
      await settle(tester);
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      // Le produit vaut maintenant 17000 pour le reste de l'app : c'est le
      // minimum de ses variantes, pas son prix nu.
      final reloaded = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      expect(reloaded!.priceFcfa, 17000);

      // ---- deuxième session : une variante sans supplément ---------------
      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => SupplierProductFormScreen(
              product: reloaded.copyWith(characteristics: const [], variants: const []),
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Couleur', value: 'Bleu');
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      final bleu = saved!.variants.firstWhere((v) => v.name == 'Bleu');
      // Le bug : 17000, le supplément de « Rouge » recompté sur une variante
      // qui n'en a pas.
      expect(bleu.priceFcfa, 15000);
      // Et « Rouge » n'a pas bougé non plus.
      expect(saved.variants.firstWhere((v) => v.name == 'Rouge').priceFcfa, 17000);

      await tester.runAsync(client.dispose);
    },
  );

  // Regression test for a second, related data bug: once a product gains a
  // variant, `stock_quantity`/`price_fcfa`/`image_urls` on `products` become
  // trigger-maintained aggregates (`product_variants_aggregate_products`,
  // `0018_product_variants.sql`). `_submit()` used to base the immediately
  // following `updateProduct` call on the product snapshot from *before*
  // this edit session — which still had the pre-variant values — silently
  // reverting whatever the trigger had just set a moment earlier. In
  // practice this made a supplier's first variant photo (and its price/
  // stock) vanish right after saving. Stock is what's asserted here
  // (easiest to drive without mocking the image picker), but it's the exact
  // same code path as the photo.
  testWidgets(
    'saving a first variant does not get silently reverted by the same '
    "submit's own product-fields update",
    (tester) async {
      await prepareSurface(tester);
      // Created with stockQuantity: 60 and no variants.
      final product = await loginAndFetchProduct(tester);

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: const Scaffold(body: SizedBox.shrink()),
          ),
        ),
      );
      await settle(tester);

      unawaited(
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Couleur', value: 'Rouge');
      // Deliberately different from the product's pre-variant stock (60) —
      // this is the trigger-computed aggregate the bug used to clobber.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Stock pour cette variante'),
        '5',
      );
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (1)'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      // The bug: this used to come back as 60 (`original.stockQuantity`,
      // carried over into the same-submit `updateProduct` call), not 5.
      expect(saved!.stockQuantity, 5);

      await tester.runAsync(client.dispose);
    },
  );
}
