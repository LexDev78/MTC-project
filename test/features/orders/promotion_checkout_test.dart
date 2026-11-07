@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mtc_app/features/orders/presentation/controllers/checkout_controller.dart';
import 'package:mtc_app/features/orders/presentation/providers/checkout_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/profile/presentation/providers/profile_providers.dart';

import '../../support/supabase_test_harness.dart';

// Ce que vaut une promotion au moment de payer (`0062`).
//
// Le point de cette fonctionnalité n'est pas l'affichage : c'est que le
// **montant facturé** baisse. `place_order` n'a jamais lu le prix envoyé par
// l'app (`0029`, `0030`) ; ces tests vérifient qu'il applique bien les
// remises lui-même, et seulement celles qui ont cours.
void main() {
  // Panier pré-semé de client2 : 2 × « Riz local 25kg » à 12 500 chez
  // Alimentation Ségou, et 1 smartphone chez Electro Bamako.
  const riceId = 'd9d25e13-71ac-51c4-93f7-ed042a996500';
  const riceSupplier = 'fournisseur6';
  const riceUnitPrice = 12500;
  const riceQuantity = 2;

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

  /// Pose une promotion sur le riz, avec la session du fournisseur qui le
  /// vend — personne d'autre ne peut le faire.
  Future<void> promoteRice(Map<String, Object?> fields) async {
    final supplierClient = createTestSupabaseClient();
    await supplierClient.auth.signInWithPassword(
      email: pseudoEmail(riceSupplier),
      password: 'password123',
    );
    await supplierClient.from('product_promotions').insert({
      'product_id': riceId,
      ...fields,
    });
    await supplierClient.dispose();
  }

  Future<int> placeOrderAndReadRiceUnitPrice() async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: 'client2', password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await container.read(addressesProvider.future);
    expect(container.read(defaultAddressProvider), isNotNull);
    await container.read(checkoutGroupsProvider.future);

    final success = await container
        .read(checkoutControllerProvider.notifier)
        .placeOrder();
    expect(success, isTrue);

    final orders = await container
        .read(orderRepositoryProvider)
        .watchOrdersForUser(DemoIds.clientMoussa)
        .first;
    final line = orders
        .expand((o) => o.supplierGroups)
        .expand((g) => g.items)
        .firstWhere((i) => i.productId == riceId);
    expect(line.quantity, riceQuantity);
    return line.unitPriceFcfaSnapshot;
  }

  test(
    'une remise en cours baisse le prix réellement facturé, sans que l\'app '
    'ait rien à envoyer',
    () async {
      await promoteRice({'kind': 'percentage', 'value': 20});

      // Le panier a été semé avec un prix figé de 12 500 : si c'était lui
      // qui comptait, la remise serait sans effet.
      expect(await placeOrderAndReadRiceUnitPrice(), 10000);
    },
  );

  test('une remise sur quantité s\'applique dès son palier', () async {
    // Le panier contient 2 unités : le palier à 2 compte, celui à 3 non.
    await promoteRice({
      'kind': 'percentage',
      'value': 10,
      'min_quantity': riceQuantity,
    });
    expect(await placeOrderAndReadRiceUnitPrice(), 11250);
  });

  test(
    'une remise dont le palier n\'est pas atteint ne change rien',
    () async {
      await promoteRice({
        'kind': 'percentage',
        'value': 50,
        'min_quantity': riceQuantity + 1,
      });
      expect(await placeOrderAndReadRiceUnitPrice(), riceUnitPrice);
    },
  );

  test('une remise expirée ne change rien', () async {
    await promoteRice({
      'kind': 'percentage',
      'value': 50,
      // En UTC explicite : une date locale sérialisée sans décalage serait
      // relue comme de l'UTC, et « il y a une minute » pourrait tomber dans
      // le futur selon le fuseau de la machine.
      'ends_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });
    expect(await placeOrderAndReadRiceUnitPrice(), riceUnitPrice);
  });

  test('une remise pas encore commencée ne change rien', () async {
    await promoteRice({
      'kind': 'percentage',
      'value': 50,
      'starts_at': DateTime.now()
          .toUtc()
          .add(const Duration(days: 7))
          .toIso8601String(),
    });
    expect(await placeOrderAndReadRiceUnitPrice(), riceUnitPrice);
  });

  test('une remise arrêtée ne change rien', () async {
    await promoteRice({
      'kind': 'percentage',
      'value': 50,
      'is_active': false,
    });
    expect(await placeOrderAndReadRiceUnitPrice(), riceUnitPrice);
  });

  test(
    'deux remises applicables ne se cumulent pas : la plus avantageuse '
    'est facturée',
    () async {
      await promoteRice({'kind': 'percentage', 'value': 10});
      await promoteRice({'kind': 'fixed_amount', 'value': 3000});

      // -10% donnerait 11 250, -3 000 F donne 9 500. Le cumul aurait donné
      // 8 250, que personne n'a voulu.
      expect(await placeOrderAndReadRiceUnitPrice(), 9500);
    },
  );

  test(
    'le total du paiement annoncé correspond au total facturé',
    () async {
      await promoteRice({'kind': 'percentage', 'value': 20});

      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'client2', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await container.read(addressesProvider.future);
      await container.read(cartItemsProvider.future);

      // Le sous-total annoncé par l'écran de paiement, remises comprises.
      final groups = await container.read(checkoutGroupsProvider.future);
      final riceGroup = groups.firstWhere(
        (g) => g.items.any((i) => i.productId == riceId),
      );
      expect(riceGroup.subtotalFcfa, 10000 * riceQuantity);

      final success = await container
          .read(checkoutControllerProvider.notifier)
          .placeOrder();
      expect(success, isTrue);

      final orders = await container
          .read(orderRepositoryProvider)
          .watchOrdersForUser(DemoIds.clientMoussa)
          .first;
      final placedGroup = orders
          .expand((o) => o.supplierGroups)
          .firstWhere((g) => g.items.any((i) => i.productId == riceId));

      // C'est tout l'enjeu : ce qui était affiché est ce qui est dû.
      expect(placedGroup.subtotalFcfa, riceGroup.subtotalFcfa);
    },
  );
}
