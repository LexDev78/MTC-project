@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;
import 'package:mtc_app/features/supplier_finance/presentation/providers/supplier_finance_providers.dart';

import '../../support/supabase_test_harness.dart';

void main() {
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

  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'a supplier with an unresolved order cannot delete their account',
    () async {
      // fournisseur5 (Electro Bamako) owns "group-awa-intransit-1", seeded
      // `in_transit` — a non-terminal status.
      await login('fournisseur5');

      await expectLater(
        container.read(authRepositoryProvider).deleteAccount(),
        throwsA(isA<ValidationException>()),
      );

      const electroBamakoId = 'dbff9b88-4829-5eed-b15a-78c33431553f';
      final state = await fetchAccountDeletionStateAsAdmin(electroBamakoId);
      expect(state.profileDeletedAt, isNull);
      expect(state.supplierDeletedAt, isNull);
    },
  );

  test(
    'a supplier with a pending payout cannot delete their account',
    () async {
      // fournisseur1 (Bogolan Bamako) has no non-terminal order groups
      // (just the seeded `delivered` one) but does have real available
      // balance from it (25000 FCFA subtotal, minus the seeded `paid`
      // 10000 payout) — enough for a fresh, small, still-`requested`
      // payout that the balance guard won't itself reject.
      await login('fournisseur1');
      await container
          .read(supplierFinanceRepositoryProvider)
          .requestPayout(
            supplierId: DemoIds.supplierBogolanBamako,
            amountFcfa: 1000,
            method: MobileMoneyProvider.moovMoney,
            payoutDestination: '+22370000000',
          );

      await expectLater(
        container.read(authRepositoryProvider).deleteAccount(),
        throwsA(isA<ValidationException>()),
      );

      final state = await fetchAccountDeletionStateAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(state.profileDeletedAt, isNull);
    },
  );

  test(
    'a supplier without unresolved orders/payouts can delete their account, '
    'and their storefront/products disappear from public view',
    () async {
      // fournisseur1 (Bogolan Bamako) has only a `delivered` order group and
      // a `paid` payout in the seed — nothing blocking.
      await login('fournisseur1');
      await container.read(authRepositoryProvider).deleteAccount();

      final state = await fetchAccountDeletionStateAsAdmin(
        DemoIds.supplierBogolanBamako,
      );
      expect(state.profileDeletedAt, isNotNull);
      expect(state.supplierDeletedAt, isNotNull);

      // From an unrelated session — the deleted storefront and its
      // products must no longer be publicly visible.
      await login('client1');
      final client = container.read(supabaseClientProvider);
      final supplierRows = await client
          .from('suppliers')
          .select()
          .eq('id', DemoIds.supplierBogolanBamako);
      expect(supplierRows, isEmpty);
      final productRows = await client
          .from('products')
          .select()
          .eq('supplier_id', DemoIds.supplierBogolanBamako);
      expect(productRows, isEmpty);
    },
  );

  test(
    'logging back into a deleted account is rejected',
    () async {
      await login('fournisseur1');
      // `deleteAccount()` already signs this session out.
      await container.read(authRepositoryProvider).deleteAccount();

      // Either lockout mechanism is an acceptable outcome here (see
      // `deactivate_account()`'s doc comment): locally, `postgres` can
      // write `auth.users.banned_until`, so GoTrue itself refuses the
      // sign-in (`InvalidCredentialsException`, its generic response for a
      // banned account) before this app's own `deleted_at` check ever
      // runs. On an environment where that write silently fails instead,
      // sign-in would succeed and `AccountDeletedException` would be the
      // one to fire during hydration — this test only asserts that
      // *logging back in is rejected one way or the other*, not which.
      await expectLater(
        container
            .read(authRepositoryProvider)
            .login(usernameOrPhone: 'fournisseur1', password: 'password123'),
        throwsA(
          anyOf(isA<AccountDeletedException>(), isA<InvalidCredentialsException>()),
        ),
      );
    },
  );

  test(
    'a client can delete their account with no blocking condition, even '
    'with past orders',
    () async {
      // client2 (Moussa) has both a delivered and an in-transit order in
      // the seed — none of that blocks a *client* from deleting, only a
      // supplier's own unresolved orders/payouts do.
      await login('client2');
      await container.read(authRepositoryProvider).deleteAccount();

      final state = await fetchAccountDeletionStateAsAdmin(DemoIds.clientMoussa);
      expect(state.profileDeletedAt, isNotNull);
    },
  );

  test('a staff account cannot delete itself', () async {
    await login('agent1');

    await expectLater(
      container.read(authRepositoryProvider).deleteAccount(),
      throwsA(isA<ValidationException>()),
    );

    final state = await fetchAccountDeletionStateAsAdmin(DemoIds.staffAgent);
    expect(state.profileDeletedAt, isNull);
  });
}
