@Tags(['integration'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/supplier_finance/domain/entities/payout_request.dart';
import 'package:mtc_app/features/supplier_finance/presentation/controllers/supplier_finance_controller.dart';
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

  // `payout_requests`/`supplier_finance_settings` have no anon-readable
  // grant — any test touching them needs a real session.
  Future<void> login(String usernameOrPhone) async {
    await container
        .read(authRepositoryProvider)
        .login(usernameOrPhone: usernameOrPhone, password: 'password123');
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'watchPayoutRequests only returns that supplier\'s own requests, and '
    'watchAllPayoutRequests returns every supplier\'s',
    () async {
      // Admin: `is_admin()` grants read of any row the query already
      // targets, so the per-supplier filters below stay meaningful (the
      // datasource's own `.eq('supplier_id', ...)` still scopes each call)
      // while `watchAllPayoutRequests` also works in the same session.
      await login('admin1');
      final repo = container.read(supplierFinanceRepositoryProvider);

      final mine = await repo
          .watchPayoutRequests(DemoIds.supplierBogolanBamako)
          .first;
      expect(mine, hasLength(1));
      expect(mine.single.id, DemoIds.payoutBogolan1);

      final none = await repo
          .watchPayoutRequests(DemoIds.supplierAlimentationSegou)
          .first;
      expect(none, isEmpty);

      final all = await repo.watchAllPayoutRequests().first;
      expect(all.any((p) => p.id == DemoIds.payoutBogolan1), isTrue);
    },
  );

  test(
    'updatePayoutStatus follows requested → processing → paid, and rejects '
    'an invalid jump or a change to a terminal request',
    () async {
      // `payout_requests_insert_own` requires the caller to actually be
      // the owning supplier.
      await login('fournisseur1');
      final repo = container.read(supplierFinanceRepositoryProvider);
      final created = await repo.requestPayout(
        supplierId: DemoIds.supplierBogolanBamako,
        amountFcfa: 1000,
        method: MobileMoneyProvider.moovMoney,
        payoutDestination: '+22370000099',
      );
      expect(created.status, PayoutStatus.requested);

      // `update_payout_status()` is admin-only (see
      // `0005_payout_status_rpc.sql`).
      await container.read(authRepositoryProvider).logout();
      await login('admin1');

      await expectLater(
        repo.updatePayoutStatus(payoutId: created.id, status: PayoutStatus.paid),
        throwsA(isA<ValidationException>()),
      );

      await repo.updatePayoutStatus(
        payoutId: created.id,
        status: PayoutStatus.processing,
      );
      await repo.updatePayoutStatus(payoutId: created.id, status: PayoutStatus.paid);

      final all = await repo.watchAllPayoutRequests().first;
      expect(all.firstWhere((p) => p.id == created.id).status, PayoutStatus.paid);

      await expectLater(
        repo.updatePayoutStatus(
          payoutId: created.id,
          status: PayoutStatus.processing,
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );

  test(
    'getSettings defaults to the platform rate until updateSettings '
    'overrides it',
    () async {
      // `supplier_finance_settings` write is staff-only (any staff role).
      await login('admin1');
      final repo = container.read(supplierFinanceRepositoryProvider);

      final defaultSettings = await repo.getSettings(
        DemoIds.supplierAlimentationSegou,
      );
      expect(defaultSettings.commissionRatePercent, 10.0);

      await repo.updateSettings(
        supplierId: DemoIds.supplierAlimentationSegou,
        commissionRatePercent: 15.0,
      );
      final updated = await repo.getSettings(DemoIds.supplierAlimentationSegou);
      expect(updated.commissionRatePercent, 15.0);
    },
  );

  test(
    'SupplierFinanceController.requestPayout resolves the operating '
    "supplier automatically and rejects an amount over the supplier's "
    'available balance',
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'fournisseur1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Seeded: two delivered groups for Bogolan Bamako — order-awa-delivered
      // (25000) and seed-order-1 (25000, the order `seed-review-1`
      // references — needs a real row to satisfy the FK now that reviews
      // live in the same relational schema, unlike the old unlinked
      // in-memory collections). Gross 50000, 10% commission → net 45000,
      // already paid out 10000 → available 35000.
      final tooMuch = await container
          .read(supplierFinanceControllerProvider.notifier)
          .requestPayout(
            amountFcfa: 40000,
            method: MobileMoneyProvider.orangeMoney,
            payoutDestination: '+22370000001',
          );
      expect(tooMuch, isFalse);

      final ok = await container
          .read(supplierFinanceControllerProvider.notifier)
          .requestPayout(
            amountFcfa: 20000,
            method: MobileMoneyProvider.orangeMoney,
            payoutDestination: '+22370000001',
          );
      expect(ok, isTrue);

      final payouts = await container
          .read(supplierFinanceRepositoryProvider)
          .watchPayoutRequests(DemoIds.supplierBogolanBamako)
          .first;
      expect(payouts.any((p) => p.amountFcfa == 20000), isTrue);
    },
  );

  test(
    'SupplierFinanceController.reviewPayout lets staff decide on any '
    "supplier's request, independent of the operating supplier",
    () async {
      await container
          .read(authRepositoryProvider)
          .login(usernameOrPhone: 'admin1', password: 'password123');
      await container.read(currentUserProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ok = await container
          .read(supplierFinanceControllerProvider.notifier)
          .reviewPayout(
            payoutId: DemoIds.payoutBogolan1,
            status: PayoutStatus.rejected,
          );
      // Already `paid` (terminal) in the seed — rejecting it is an invalid
      // transition, surfaced as a controlled failure rather than a crash.
      expect(ok, isFalse);
    },
  );
}
