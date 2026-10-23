@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/shop/shop.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_characteristic.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_characteristic_type.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_variant.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../support/supabase_test_harness.dart';

// IDs shared by both tests' fixture (built by [_createNoirRougeProduct]):
// "Noir" bundles all three sizes together on one variant, "Rouge" only
// offers 46/48.
const _couleurCharId = 'test-char-couleur';
const _tailleCharId = 'test-char-taille';
const _noirId = 'test-opt-noir';
const _rougeId = 'test-opt-rouge';
const _t42 = 'test-opt-42';
const _t46 = 'test-opt-46';
const _t48 = 'test-opt-48';
const _variantNoirId = 'test-variant-noir';
const _variantRougeId = 'test-variant-rouge';

/// Signs in as `fournisseur1`, creates a fresh product, and gives it two
/// variants: "Noir" (sizes 42/46/48 bundled together, one shared
/// price/stock) and "Rouge" (only 46/48) — the exact shape a supplier
/// reported hitting the picker's old exact-match bug with. Must itself run
/// inside `tester.runAsync`.
Future<Product> _createNoirRougeProduct(ProviderContainer container) {
  return () async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'fournisseur1', password: 'password123');
    await container.read(currentUserProvider.future);
    final user = container.read(currentUserProvider).value! as SupplierTiersUser;
    final supplierId = container.read(operatingSupplierIdProvider)!;
    final supplierProfile = await container.read(supplierRepositoryProvider).getById(
      supplierId,
    );
    final repo = container.read(productRepositoryProvider);

    final created = await repo.createProduct(
      supplierId: supplierId,
      supplierName: supplierProfile.businessName,
      supplierType: SupplierType.tiers,
      isSupplierVerified: user.verificationStatus == VerificationStatus.verified,
      name: 'Chaussure test tailles multiples',
      description: 'Produit créé pour tester le sélecteur de variantes.',
      category: ProductCategory.autre,
      priceFcfa: 20000,
      stockQuantity: 0,
      weightKg: 1.0,
      city: 'Bamako',
      imageUrls: const [],
      allowsSelfDelivery: true,
      allowsMtcDelivery: true,
      sizes: const [],
      colors: const [],
      region: ProductRegion.mali,
    );

    final couleurType = ProductCharacteristicType(
      id: 'couleur',
      label: 'Couleur',
      status: CharacteristicTypeStatus.approved,
      createdAt: DateTime.now(),
    );
    final tailleType = ProductCharacteristicType(
      id: 'taille',
      label: 'Taille',
      status: CharacteristicTypeStatus.approved,
      createdAt: DateTime.now(),
    );

    await repo.replaceCharacteristicsAndVariants(
      productId: created.id,
      characteristics: [
        ProductCharacteristic(
          id: _couleurCharId,
          productId: created.id,
          type: couleurType,
          displayOrder: 0,
          options: const [
            ProductCharacteristicOption(
              id: _noirId,
              characteristicId: _couleurCharId,
              value: 'Noir',
              priceDeltaFcfa: 0,
              displayOrder: 0,
            ),
            ProductCharacteristicOption(
              id: _rougeId,
              characteristicId: _couleurCharId,
              value: 'Rouge',
              priceDeltaFcfa: 0,
              displayOrder: 1,
            ),
          ],
        ),
        ProductCharacteristic(
          id: _tailleCharId,
          productId: created.id,
          type: tailleType,
          displayOrder: 1,
          options: const [
            ProductCharacteristicOption(
              id: _t42,
              characteristicId: _tailleCharId,
              value: '42',
              priceDeltaFcfa: 0,
              displayOrder: 0,
            ),
            ProductCharacteristicOption(
              id: _t46,
              characteristicId: _tailleCharId,
              value: '46',
              priceDeltaFcfa: 0,
              displayOrder: 1,
            ),
            ProductCharacteristicOption(
              id: _t48,
              characteristicId: _tailleCharId,
              value: '48',
              priceDeltaFcfa: 0,
              displayOrder: 2,
            ),
          ],
        ),
      ],
      variants: [
        // "Noir" — sold in all three sizes together, sharing one price/stock.
        ProductVariant(
          id: _variantNoirId,
          productId: created.id,
          name: 'Noir 42 46 48',
          priceFcfa: 20000,
          stockQuantity: 30,
          imageUrls: const [],
          isDefault: true,
          displayOrder: 0,
          optionRefs: const [
            ProductVariantOptionRef(characteristicId: _couleurCharId, optionId: _noirId),
            ProductVariantOptionRef(characteristicId: _tailleCharId, optionId: _t42),
            ProductVariantOptionRef(characteristicId: _tailleCharId, optionId: _t46),
            ProductVariantOptionRef(characteristicId: _tailleCharId, optionId: _t48),
          ],
        ),
        // "Rouge" — only 46 and 48, deliberately *not* 42, so the client's
        // carried-over size selection (42, from "Noir") can't possibly
        // match it exactly.
        ProductVariant(
          id: _variantRougeId,
          productId: created.id,
          name: 'Rouge 46 48',
          priceFcfa: 25000,
          stockQuantity: 10,
          imageUrls: const [],
          isDefault: false,
          displayOrder: 1,
          optionRefs: const [
            ProductVariantOptionRef(characteristicId: _couleurCharId, optionId: _rougeId),
            ProductVariantOptionRef(characteristicId: _tailleCharId, optionId: _t46),
            ProductVariantOptionRef(characteristicId: _tailleCharId, optionId: _t48),
          ],
        ),
      ],
    );

    return created;
  }();
}

// Regression test for a real bug: the client-side variant picker used to
// resolve a tap by requiring the *exact same* combination for every other
// characteristic to already be selected — fine when each variant carries
// exactly one option per characteristic, but a variant can now list several
// (`0028_multi_option_variant_options.sql`, e.g. one "Noir" variant sold in
// sizes 42/46/48 together). Reproduces the exact shape a supplier reported:
// "Noir" offering 42/46/48, "Rouge" only offering 46/48 — tapping "Rouge"
// while the client's currently-recorded size happened to be 42 (a value
// "Rouge" doesn't have) used to silently do nothing, since no variant
// matched {couleur: Rouge, taille: 42} exactly.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  // `_FicheState.initState` defers its default-variant
  // selection via a bare `Future(() {...})` (a zero-duration `Timer.run`,
  // per Riverpod's own recommendation for "can't write a provider
  // synchronously from initState") — a duration-less `pump()` alone doesn't
  // reliably let that fire under the test binding's fake clock; a couple of
  // real (if tiny) `pump(duration)` calls do.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Opens the purchase sheet — the kit's product page keeps the variant
/// picker there, behind the bottom "Acheter" button, not on the page.
Future<void> openPurchaseSheet(WidgetTester tester) async {
  await tester.tap(find.text('Acheter'));
  await settle(tester);
}

/// The purchase sheet's own bottom button (the page's is underneath it).
CartButton sheetButton(WidgetTester tester) =>
    tester.widget<CartButton>(find.byType(CartButton).last);

// IDs for [_createBundledSizeOnlyProduct]'s fixture — a single characteristic
// ("taille") bundled two different ways across two *disjoint* variants
// (Groupe1: S/M, Groupe2: L/XL, sharing no size), so switching between them
// is never blocked by `reachable()`'s combination check: with only one
// characteristic on the whole product, there's no *other* characteristic
// left for that check to compare against, so it's vacuously satisfied and
// every size stays reachable. That isolates the second regression below from
// the first: any variant offering the tapped size is always a legal switch,
// so if the destination remains ambiguous, it's `derivePicks`' carry-over —
// not `reachable()` — that has to resolve it.
const _tailleOnlyCharId = 'test-char-taille-only';
const _sId = 'test-opt-s';
const _mId = 'test-opt-m';
const _lId = 'test-opt-l';
const _xlId = 'test-opt-xl';
const _variantGroup1Id = 'test-variant-group1';
const _variantGroup2Id = 'test-variant-group2';

Future<Product> _createBundledSizeOnlyProduct(ProviderContainer container) {
  return () async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'fournisseur1', password: 'password123');
    await container.read(currentUserProvider.future);
    final user = container.read(currentUserProvider).value! as SupplierTiersUser;
    final supplierId = container.read(operatingSupplierIdProvider)!;
    final supplierProfile = await container.read(supplierRepositoryProvider).getById(
      supplierId,
    );
    final repo = container.read(productRepositoryProvider);

    final created = await repo.createProduct(
      supplierId: supplierId,
      supplierName: supplierProfile.businessName,
      supplierType: SupplierType.tiers,
      isSupplierVerified: user.verificationStatus == VerificationStatus.verified,
      name: 'Chaussure test tailles disjointes',
      description: 'Produit créé pour tester le report de choix ambigu.',
      category: ProductCategory.autre,
      priceFcfa: 20000,
      stockQuantity: 0,
      weightKg: 1.0,
      city: 'Bamako',
      imageUrls: const [],
      allowsSelfDelivery: true,
      allowsMtcDelivery: true,
      sizes: const [],
      colors: const [],
      region: ProductRegion.mali,
    );

    final tailleType = ProductCharacteristicType(
      id: 'taille',
      label: 'Taille',
      status: CharacteristicTypeStatus.approved,
      createdAt: DateTime.now(),
    );

    await repo.replaceCharacteristicsAndVariants(
      productId: created.id,
      characteristics: [
        ProductCharacteristic(
          id: _tailleOnlyCharId,
          productId: created.id,
          type: tailleType,
          displayOrder: 0,
          options: const [
            ProductCharacteristicOption(
              id: _sId,
              characteristicId: _tailleOnlyCharId,
              value: 'S',
              priceDeltaFcfa: 0,
              displayOrder: 0,
            ),
            ProductCharacteristicOption(
              id: _mId,
              characteristicId: _tailleOnlyCharId,
              value: 'M',
              priceDeltaFcfa: 0,
              displayOrder: 1,
            ),
            ProductCharacteristicOption(
              id: _lId,
              characteristicId: _tailleOnlyCharId,
              value: 'L',
              priceDeltaFcfa: 0,
              displayOrder: 2,
            ),
            ProductCharacteristicOption(
              id: _xlId,
              characteristicId: _tailleOnlyCharId,
              value: 'XL',
              priceDeltaFcfa: 0,
              displayOrder: 3,
            ),
          ],
        ),
      ],
      variants: [
        ProductVariant(
          id: _variantGroup1Id,
          productId: created.id,
          name: 'Groupe1 S M',
          priceFcfa: 20000,
          stockQuantity: 20,
          imageUrls: const [],
          isDefault: true,
          displayOrder: 0,
          optionRefs: const [
            ProductVariantOptionRef(characteristicId: _tailleOnlyCharId, optionId: _sId),
            ProductVariantOptionRef(characteristicId: _tailleOnlyCharId, optionId: _mId),
          ],
        ),
        // Disjoint from Groupe1 — shares no size with it — so a tap on "L"
        // or "XL" always has to switch variants, never resolves via
        // `onPick` directly.
        ProductVariant(
          id: _variantGroup2Id,
          productId: created.id,
          name: 'Groupe2 L XL',
          priceFcfa: 20000,
          stockQuantity: 15,
          imageUrls: const [],
          isDefault: false,
          displayOrder: 1,
          optionRefs: const [
            ProductVariantOptionRef(characteristicId: _tailleOnlyCharId, optionId: _lId),
            ProductVariantOptionRef(characteristicId: _tailleOnlyCharId, optionId: _xlId),
          ],
        ),
      ],
    );

    return created;
  }();
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
        // Not under test here, and its underlying `watchProducts` now rides
        // a real Postgres realtime channel (`_productRealtimeTrigger`) —
        // its own reconnect/backoff timers otherwise easily outlive the
        // test body and trip `flutter_test`'s "no pending timers" check.
        similarProductsProvider.overrideWith((ref, product) => Stream.value(const [])),
      ],
    );
    // Disposed explicitly at the end of the test body below, not via
    // `addTearDown` — `addTearDown` callbacks run *after* `flutter_test`'s "no pending
    // timers" invariant check, too late to avoid tripping it.
  });

  testWidgets(
    'tapping a color whose own variant offers different sizes than the '
    'currently selected one still switches to it, instead of doing nothing',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = await tester.runAsync(() => _createNoirRougeProduct(container));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ProductDetailScreen(productId: product!.id)),
        ),
      );
      await settle(tester);
      await openPurchaseSheet(tester);

      // Starts on the default "Noir" variant (stock 30).
      expect(find.text('30 en stock'), findsOneWidget);

      // Tap "Rouge" — must switch to it (stock 10) even though the
      // currently-shown size chip is "42", which "Rouge" doesn't offer.
      await tester.tap(find.text('Rouge'));
      await settle(tester);

      expect(find.text('10 en stock'), findsOneWidget);
      expect(find.text('30 en stock'), findsNothing);

      container.dispose();
      await tester.runAsync(client.dispose);
    },
  );

  testWidgets(
    'a variant bundling several sizes requires picking exactly one before '
    'checkout, and only that one size reaches the cart',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = await tester.runAsync(() => _createNoirRougeProduct(container));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ProductDetailScreen(productId: product!.id)),
        ),
      );
      await settle(tester);
      await openPurchaseSheet(tester);

      // "Noir" bundles three sizes with nothing picked yet — the client is
      // prompted, and both purchase buttons are disabled.
      expect(find.text('Choisissez une valeur.'), findsOneWidget);
      expect(find.text('Choisir : taille'), findsOneWidget);
      expect(sheetButton(tester).onPressed, isNull);

      // Tapping "46" resolves the choice: only that chip highlights (not
      // 42 or 48 too), and the buttons unlock.
      await tester.tap(find.text('46'));
      await settle(tester);

      expect(find.text('Choisissez une valeur.'), findsNothing);
      expect(find.text('Choisir : taille'), findsNothing);
      expect(find.text('Ajouter au panier'), findsOneWidget);
      expect(sheetButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Ajouter au panier'));
      await settle(tester);

      final cartItems = await tester.runAsync(() async {
        final userId = container.read(currentUserProvider).value!.id;
        return container.read(cartRepositoryProvider).watchCart(userId).first;
      });
      expect(cartItems, hasLength(1));
      // Only "46" reached the cart, not the supplier's raw bundled
      // "Noir 42 46 48" name.
      expect(cartItems!.single.variantNameSnapshot, 'Noir 46');

      container.dispose();
      await tester.runAsync(client.dispose);
    },
  );

  // Regression test for a second, related bug: switching variants via a tap
  // used to only ever set `productVariantIdProvider`, never record the
  // tapped option itself — so when the *destination* variant was itself
  // bundled on that same characteristic, pure carry-over (`derivePicks`)
  // had nothing to carry over, and the tap looked like it did nothing
  // ("Choisissez une valeur." stayed up) until an identical second tap
  // resolved it. Uses [_createBundledSizeOnlyProduct] rather than the
  // Noir/Rouge fixture above — a second characteristic there would let
  // `reachable()`'s combination check block the very tap this test needs to
  // make (see that fixture's own doc comment).
  testWidgets(
    'tapping a size that only exists on a different variant group resolves '
    'that size immediately, even though the destination group is itself '
    'bundled on sizes',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final product = await tester.runAsync(() => _createBundledSizeOnlyProduct(container));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: ProductDetailScreen(productId: product!.id)),
        ),
      );
      await settle(tester);
      await openPurchaseSheet(tester);

      // Starts on the default "Groupe1" (S/M), nothing picked yet.
      expect(find.text('20 en stock'), findsOneWidget);
      expect(find.text('Choisissez une valeur.'), findsOneWidget);

      // "L" only exists on "Groupe2" — tapping it must switch groups *and*
      // resolve the size in that same tap, not leave it ambiguous (Groupe2
      // also bundles two sizes, L and XL).
      await tester.tap(find.text('L'));
      await settle(tester);

      expect(find.text('15 en stock'), findsOneWidget); // now on "Groupe2"
      expect(find.text('Choisissez une valeur.'), findsNothing);
      expect(sheetButton(tester).onPressed, isNotNull);

      container.dispose();
      await tester.runAsync(client.dispose);
    },
  );
}
