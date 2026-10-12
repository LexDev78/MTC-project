@Tags(['integration'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/screens/supplier_product_form_screen.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/supplier_providers.dart';

import '../../support/supabase_test_harness.dart';

// End-to-end check of the "compose one variant at a time" flow: pick a
// characteristic type, give it a value (+ optional extra cost), repeat to
// add a second field to the same variant, add it to the list, then save —
// mirrors exactly how a supplier builds e.g. "iPhone 17Pro 256Go Noir" one
// combination at a time (see the plan's rappel from the user).
//
// Three `testWidgets` traps this file has to route around:
//
// 1. Never `pumpAndSettle()`: `AsyncValueWidget`'s loading state
//    (`MtcLoadingView`) is a perpetually-animating spinner while
//    `approvedCharacteristicTypesProvider` loads, which `pumpAndSettle()`
//    waits forever on (same trap `widget_test.dart`'s own comment already
//    warns about for the splash screen's ticker).
// 2. `testWidgets` runs under `AutomatedTestWidgetsFlutterBinding`, whose
//    fake clock pauses real `Timer`s — a real Supabase request's
//    completion depends on `dart:io HttpClient`'s own internal timers, so
//    it needs `tester.runAsync()` (which runs its callback in the real,
//    unpaused time zone) both for calls made before the first pump (e.g.
//    logging in) and, via [settle], interleaved with `pump()` so widget
//    rebuilds keep reflecting newly-arrived data.
// 3. That same real `HttpClient` leaves an idle keep-alive `Timer` running
//    after the last request completes, which trips `flutter_test`'s "no
//    pending timers after the test" invariant unless the client is
//    disposed *before* the test body returns (a teardown callback runs too
//    late — the binding's own invariant check happens first).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
}

/// Un passage complet du dialogue « Ajouter un champ » : type puis valeur.
/// [value] accepte plusieurs valeurs séparées par des virgules, qui
/// atterrissent toutes sur la variante en cours.
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

/// Comme [addField], avec un coût supplémentaire sur la ou les valeurs.
Future<void> addFieldWithCost(
  WidgetTester tester, {
  required String typeLabel,
  required String value,
  required int cost,
}) async {
  await tester.tap(find.text('Ajouter un champ'));
  await settle(tester);
  await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
  await settle(tester);
  await tester.tap(find.text(typeLabel).last);
  await settle(tester);
  await tester.enterText(find.byKey(const Key('add-field-value-input')), value);
  await settle(tester);
  await tester.tap(find.byKey(const Key('add-field-extra-cost-checkbox')));
  await settle(tester);
  await tester.enterText(find.byKey(const Key('add-field-delta-input')), '$cost');
  await settle(tester);
  await tester.tap(find.text('Ajouter').last);
  await settle(tester);
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
  // (`0021_backfill_default_variants_and_require_variant.sql`), which
  // `VariantManagerPanel` loads into its draft on open — every
  // variant-count/characteristic assertion below assumes composing a
  // variant completely from scratch, so the fixture has to actually start
  // with none.
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
        name: 'Produit test variantes',
        description: 'Produit créé pour tester la composition de variantes.',
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

  /// Tall enough that every widget this test taps stays within the test
  /// surface (no `SingleChildScrollView` scrolling needed as the variant
  /// list grows), and disposes the real Supabase client *before* returning
  /// — see trap 3 above.
  Future<void> prepareSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'composing fields one at a time builds a variant, which persists on save',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);
      expect(product.hasVariants, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      expect(find.text('Ajouter un champ'), findsOneWidget);

      // ---- first field: couleur = Noir -----------------------------------
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);

      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);

      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'Noir');
      await settle(tester);
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);

      expect(find.text('Couleur : Noir'), findsOneWidget);

      // ---- second field: stockage = 256 (Go), +5000 FCFA -----------------
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);

      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Stockage').last);
      await settle(tester);

      await tester.enterText(find.byKey(const Key('add-field-value-input')), '256');
      await tester.tap(find.byKey(const Key('add-field-extra-cost-checkbox')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-delta-input')), '5000');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);

      expect(find.text('Stockage : 256 Go (+5000)'), findsOneWidget);

      // ---- confirm the variant --------------------------------------------
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      expect(find.text('Noir 256 Go'), findsOneWidget);
      expect(find.text('Variantes (1)'), findsOneWidget);
      // 15000 (the fresh product's base price) + 5000 delta.
      expect(find.widgetWithText(TextField, '20000'), findsOneWidget);

      // ---- save, then verify it actually persisted -------------------------
      // The single "Enregistrer" button saves the product's own fields and
      // this characteristics/variants draft together (see
      // `supplier_product_form_screen.dart`'s `_submit`).
      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      expect(saved!.hasVariants, isTrue);
      expect(saved.variants, hasLength(1));
      final variant = saved.variants.single;
      expect(variant.name, 'Noir 256 Go');
      expect(variant.priceFcfa, 20000);
      expect(variant.optionRefs, hasLength(2));

      expect(saved.characteristics.map((c) => c.type.id).toSet(), {'couleur', 'stockage'});
      final stockageOption = saved.characteristics
          .firstWhere((c) => c.type.id == 'stockage')
          .options
          .single;
      expect(stockageOption.value, '256 Go');
      expect(stockageOption.priceDeltaFcfa, 5000);

      await tester.runAsync(client.dispose);
    },
  );

  testWidgets(
    'reusing an existing value inherits its price delta instead of asking again',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      // First variant: couleur = Noir, +2000.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'Noir');
      await tester.tap(find.byKey(const Key('add-field-extra-cost-checkbox')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-delta-input')), '2000');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      // Second variant: reuse couleur = Noir via the "already used" chip —
      // its delta (+2000) should be inherited, not re-asked.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);

      expect(find.textContaining('Valeurs déjà utilisées'), findsOneWidget);
      await tester.tap(find.text('Noir (+2000)'));
      await settle(tester);
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);

      expect(find.text('Couleur : Noir (+2000)'), findsOneWidget);

      // Distinguish the two variants so they don't collide (both would
      // otherwise be plain "Noir").
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Taille').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'L');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      expect(find.text('Variantes (2)'), findsOneWidget);
      // Both variants' price fields read 17000 (15000 base + 2000 delta) —
      // proof the second variant's Noir reused the first's delta.
      expect(find.widgetWithText(TextField, '17000'), findsNWidgets(2));

      await tester.runAsync(client.dispose);
    },
  );

  // Regression test for a real bug: typing a value that already exists in
  // the pool (rather than tapping its chip) used to silently keep that
  // option's *old* price, discarding whatever was just entered in "Coût
  // supplémentaire ?" — so a value pre-defined with no price (e.g. via
  // "Ajouter des valeurs", which never asks for one) could never be priced
  // afterwards through any path in this screen.
  testWidgets(
    'retyping an existing value with a new price updates it for this and '
    'future variants, instead of silently keeping the old price',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      // First variant: couleur = Noir, no extra cost.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'Noir');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      // Both the product's own base-price field and this delta-less
      // variant's price field read "15000" at this point — `findsWidgets`
      // rather than `findsOneWidget`, since which one is which isn't what
      // this test is about.
      expect(find.widgetWithText(TextField, '15000'), findsWidgets);

      // Second variant: *retype* "Noir" (free text, not the chip) with a
      // new +3000 price — this must actually apply now.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Couleur').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'Noir');
      await tester.tap(find.byKey(const Key('add-field-extra-cost-checkbox')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-delta-input')), '3000');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);

      expect(find.text('Couleur : Noir (+3000)'), findsOneWidget);

      // Distinguish the two variants so they don't collide.
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Taille').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'L');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      expect(find.text('Variantes (2)'), findsOneWidget);
      expect(find.widgetWithText(TextField, '18000'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      // The pool's "Noir" option itself now carries the updated price, not
      // just a snapshot on this one variant.
      final noirOption = saved!.characteristics
          .firstWhere((c) => c.type.id == 'couleur')
          .options
          .single;
      expect(noirOption.value, 'Noir');
      expect(noirOption.priceDeltaFcfa, 3000);

      await tester.runAsync(client.dispose);
    },
  );

  testWidgets(
    'entering "S, M, L" for Taille in one go creates three sizes, ready to '
    'pick from on the next variant instead of retyping them',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      // First variant: bulk-enter "S, M, L" for Taille in one field instead
      // of repeating "Ajouter un champ" per size.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Taille').last);
      await settle(tester);
      await tester.enterText(find.byKey(const Key('add-field-value-input')), 'S, M, L');
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);

      // The first of the three resolves as this variant's own field...
      expect(find.text('Taille : S'), findsOneWidget);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (1)'), findsOneWidget);

      // ...while M and L are already in the pool, selectable as reuse chips
      // on the next variant — not one option literally named "S, M, L".
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Taille').last);
      await settle(tester);

      // Scoped to the dialog: the first variant's tile also shows "S" as
      // its own auto-generated name (its only field), so a bare `find.text`
      // would match both.
      Finder inDialog(String text) =>
          find.descendant(of: find.byType(AlertDialog), matching: find.text(text));
      expect(find.textContaining('Valeurs déjà utilisées'), findsOneWidget);
      expect(inDialog('S'), findsOneWidget);
      expect(inDialog('M'), findsOneWidget);
      expect(inDialog('L'), findsOneWidget);
      expect(find.text('S, M, L'), findsNothing);

      await tester.tap(inDialog('M'));
      await settle(tester);
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      expect(find.text('Taille : M'), findsOneWidget);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      expect(find.text('Variantes (2)'), findsOneWidget);

      await tester.runAsync(client.dispose);
    },
  );

  // Le pool de valeurs d'un produit n'a plus de porte d'entrée à lui : il
  // se remplit tout seul au fil des variantes composées (voir le
  // commentaire du panneau, d'où "Ajouter des valeurs" a été retiré). Ce
  // test suit donc le chemin restant — une valeur saisie pour une première
  // variante doit revenir en pastille réutilisable sur la suivante, sans
  // avoir à la retaper ni à créer de doublon.
  testWidgets(
    'a value typed for one variant comes back as a reuse chip on the next, '
    'and picking it adds no duplicate option',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Taille', value: 'S');
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (1)'), findsOneWidget);

      // Deuxième variante : "S" est maintenant dans le pool du produit.
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await tester.tap(find.text('Ajouter un champ'));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-field-type-dropdown')));
      await settle(tester);
      await tester.tap(find.text('Taille').last);
      await settle(tester);

      expect(find.textContaining('Valeurs déjà utilisées'), findsOneWidget);
      final inDialog = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('S'),
      );
      expect(inDialog, findsOneWidget);
      await tester.tap(inDialog);
      await settle(tester);
      await tester.tap(find.text('Ajouter').last);
      await settle(tester);
      expect(find.text('Taille : S'), findsOneWidget);

      // Une deuxième valeur, tapée celle-là, pour que la combinaison diffère
      // de la première variante (sinon elle est refusée comme doublon).
      await addField(tester, typeLabel: 'Couleur', value: 'Rouge');
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);
      expect(find.text('Variantes (2)'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      // La pastille réutilisée pointe sur l'option existante : une seule
      // valeur "S" dans la caractéristique Taille, pas deux.
      final tailles = saved!.characteristics
          .firstWhere((c) => c.type.id == 'taille')
          .options
          .map((o) => o.value)
          .toList();
      expect(tailles, ['S']);

      await tester.runAsync(client.dispose);
    },
  );

  // Exemple donné en usage : « iPhone 16 512 Go » et « 1 To » réunis sur une
  // seule variante. Le calcul additionnait les deux suppléments, donnant le
  // prix des deux stockages cumulés — alors que l'acheteur n'en prend qu'un.
  testWidgets(
    'deux valeurs d\'une même caractéristique à des prix différents sont '
    'refusées, au lieu d\'additionner leurs suppléments',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester); // 15000, sans variante

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addFieldWithCost(tester, typeLabel: 'Stockage', value: '512', cost: 50000);
      await addFieldWithCost(tester, typeLabel: 'Stockage', value: '1024', cost: 120000);

      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      // Refusée, avec un motif qui nomme la caractéristique fautive.
      expect(find.textContaining('n\'ont pas le même supplément'), findsOneWidget);
      expect(find.text('Variantes (1)'), findsNothing);

      await tester.runAsync(client.dispose);
    },
  );

  // Le pendant légitime : plusieurs valeurs d'une même caractéristique
  // vendues ensemble **au même prix**. Le supplément ne doit alors compter
  // qu'une fois, pas une fois par valeur.
  testWidgets(
    'plusieurs valeurs au même supplément ne le comptent qu\'une fois',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester); // 15000

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addFieldWithCost(tester, typeLabel: 'Taille', value: 'S, M', cost: 2000);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      expect(find.text('Variantes (1)'), findsOneWidget);
      // 15000 + 2000 une seule fois, et non 15000 + 2000 + 2000.
      expect(find.widgetWithText(TextField, '17000'), findsOneWidget);

      await tester.runAsync(client.dispose);
    },
  );

  testWidgets(
    'a single variant can carry several sizes at once, sharing one price '
    'and stock instead of needing one variant per size',
    (tester) async {
      await prepareSurface(tester);
      final product = await loginAndFetchProduct(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SupplierProductFormScreen(product: product)),
        ),
      );
      await settle(tester);

      // Les deux tailles en une seule saisie, séparées par une virgule :
      // le dialogue les crée toutes les deux et les attache à la variante
      // en cours (c'est ce que remplace l'ancien "Ajouter des valeurs").
      await tester.tap(find.text('Ajouter une variante'));
      await settle(tester);
      await addField(tester, typeLabel: 'Taille', value: 'S, M');

      expect(find.text('Taille : S'), findsOneWidget);
      expect(find.text('Taille : M'), findsOneWidget);
      await tester.tap(find.text('Ajouter cette variante'));
      await settle(tester);

      // Still one variant — S and M live together on it, not split apart.
      expect(find.text('Variantes (1)'), findsOneWidget);

      await tester.tap(find.text('Enregistrer'));
      await settle(tester);

      final saved = await tester.runAsync(
        () => container.read(productRepositoryProvider).getById(product.id),
      );
      expect(saved!.variants, hasLength(1));
      final variant = saved.variants.single;
      expect(variant.optionRefs, hasLength(2));
      final sizeValues = variant.optionRefs
          .map(
            (r) => saved.characteristics
                .expand((c) => c.options)
                .firstWhere((o) => o.id == r.optionId)
                .value,
          )
          .toSet();
      expect(sizeValues, {'S', 'M'});

      await tester.runAsync(client.dispose);
    },
  );
}
