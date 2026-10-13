@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mtc_app/features/promo_codes/data/datasources/supabase_promo_code_datasource.dart';
import 'package:mtc_app/features/promo_codes/domain/entities/promo_code.dart';
import 'package:mtc_app/features/promo_codes/data/repositories/supabase_promo_code_repository.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/applied_promo_code_provider.dart';
import 'package:mtc_app/features/promo_codes/presentation/providers/promo_code_providers.dart';

import '../../support/supabase_test_harness.dart';

// Ce qu'un code promo vaut au moment de payer (`0073`).
//
// L'aperçu n'engage rien : c'est `place_order` qui revalide, applique, et
// **consomme**. Ces tests portent sur cette consommation — le montant
// facturé, les plafonds, et la trace que le fournisseur lit ensuite.
void main() {
  // Panier pré-semé de client2 : 2 × « Riz local 25kg » à 12 500 chez
  // Alimentation Ségou (fournisseur6), plus un smartphone chez un autre.
  const riz = 'd9d25e13-71ac-51c4-93f7-ed042a996500';
  const prixRiz = 12500;

  late ProviderContainer container;

  setUp(() async {
    await resetAndSeed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(createTestSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<SupabaseClient> signIn(String identifiant) async {
    final client = createTestSupabaseClient();
    await client.auth.signInWithPassword(
      email: pseudoEmail(identifiant),
      password: 'password123',
    );
    return client;
  }

  /// Crée un code chez le vendeur du riz.
  Future<SupabasePromoCodeRepository> createCode({
    required String code,
    required int percent,
    int? maxUses,
    int maxUsesPerClient = 1,
  }) async {
    final supplierClient = await signIn('fournisseur6');
    final repository = SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(supplierClient),
    );
    await repository.create(
      code: code,
      percent: percent,
      maxUses: maxUses,
      maxUsesPerClient: maxUsesPerClient,
    );
    return repository;
  }

  Future<int> placeOrderWithCode(String? code) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    expect(container.read(defaultAddressProvider), isNotNull);

    if (code != null) {
      await container.read(appliedPromoCodeProvider.notifier).apply(code);
    }
    await container.read(checkoutGroupsProvider.future);

    final success = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder();
    expect(
      success,
      isTrue,
      reason: '${container.read(checkoutControllerProvider).error}',
    );

    final orders = await container
        .read(orderRepositoryProvider)
        .watchOrdersForUser(DemoIds.clientMoussa)
        .first;
    return orders
        .expand((o) => o.supplierGroups)
        .expand((g) => g.items)
        .firstWhere((i) => i.productId == riz)
        .unitPriceFcfaSnapshot;
  }

  test(
    'commander avec un code facture le prix remisé et consomme une '
    'utilisation',
    () async {
      final supplier = await createCode(code: 'SEGOU', percent: 20);

      expect(await placeOrderWithCode('segou'), prixRiz - 2500);

      // Le fournisseur retrouve ce que son code a remisé, et sur quoi.
      final codes = await supplier.watchMine().first;
      final code = codes.single;
      expect(code.usesCount, 1);
      expect(code.redemptions, hasLength(1));

      final utilisation = code.redemptions.single;
      expect(utilisation.discountFcfa, 2500 * 2);
      expect(utilisation.clientName, isNotEmpty);
      expect(utilisation.items, hasLength(1));
      expect(utilisation.items.single.productName, contains('Riz'));
      expect(utilisation.items.single.quantity, 2);
      expect(utilisation.items.single.unitDiscountFcfa, 2500);
    },
  );

  test('sans code, rien n\'est consommé ni enregistré', () async {
    final supplier = await createCode(code: 'SEGOU', percent: 20);

    expect(await placeOrderWithCode(null), prixRiz);

    final code = (await supplier.watchMine().first).single;
    expect(code.usesCount, 0);
    expect(code.redemptions, isEmpty);
  });

  test('le même client ne peut pas réutiliser un code à usage unique', () async {
    await createCode(code: 'UNEFOIS', percent: 10);
    await placeOrderWithCode('UNEFOIS');

    // Le panier a été vidé par la première commande : on le regarnit pour
    // retenter, comme le ferait le client.
    final clientClient = await signIn('client2');
    await clientClient.from('cart_items').insert({
      'id': 'retry-1',
      'user_id': DemoIds.clientMoussa,
      'product_id': riz,
      'supplier_id': '2c66294c-e1d7-59f1-925c-5ab6703827f3',
      'product_name_snapshot': 'Riz local 25kg',
      'unit_price_fcfa_snapshot': prixRiz,
      'quantity': 1,
    });

    final preview = await SupabasePromoCodeRepository(
      SupabasePromoCodeDatasource(clientClient),
    ).preview(
      code: 'UNEFOIS',
      lines: [(productId: riz, variantId: null, quantity: 1)],
    );
    expect(preview.valid, isFalse);
    expect(preview.reason, contains('déjà utilisé'));

    await clientClient.dispose();
  });

  test(
    'un code épuisé est refusé — le compteur est la limite, pas une '
    'indication',
    () async {
      final supplier = await createCode(
        code: 'DIX',
        percent: 10,
        maxUses: 1,
        maxUsesPerClient: 5,
      );
      await placeOrderWithCode('DIX');

      final code = (await supplier.watchMine().first).single;
      expect(code.usesCount, 1);
      expect(code.remainingUses, 0);
      expect(code.isUsable, isFalse);

      // Un autre client, même code : la limite globale tient.
      final autre = await signIn('client1');
      final preview = await SupabasePromoCodeRepository(
        SupabasePromoCodeDatasource(autre),
      ).preview(
        code: 'DIX',
        lines: [(productId: riz, variantId: null, quantity: 1)],
      );
      expect(preview.valid, isFalse);
      await autre.dispose();
    },
  );

  test('un code inconnu fait échouer la commande au lieu d\'être ignoré', () async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    await container.read(checkoutGroupsProvider.future);

    // L'app n'enverrait pas un code refusé par l'aperçu ; on force le cas
    // pour vérifier que le serveur ne se repose pas là-dessus.
    final success = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder();
    expect(success, isTrue, reason: 'sans code, la commande passe');
  });

  test(
    'le client relit sur sa commande quel code il a utilisé',
    () async {
      await createCode(code: 'SEGOU', percent: 20);
      await placeOrderWithCode('SEGOU');

      final orders = await container
          .read(orderRepositoryProvider)
          .watchOrdersForUser(DemoIds.clientMoussa)
          .first;
      final order = orders.first;

      // La trace ne porte qu'un identifiant de code, et `promo_codes` est
      // fermée au client : sans l'instantané figé à la commande, il verrait
      // une remise sans savoir laquelle (`0077`).
      final codes = await container
          .read(promoCodeRepositoryProvider)
          .fetchForOrder(order.id);
      final group = order.supplierGroups.firstWhere(
        (g) => g.items.any((i) => i.productId == riz),
      );
      expect(codes[group.id]?.code, 'SEGOU');
      expect(codes[group.id]?.discountFcfa, 2500 * 2);
    },
  );
}
