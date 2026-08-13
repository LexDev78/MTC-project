import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/constants/app_constants.dart';
import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';

import '../../data/datasources/supabase_supplier_finance_datasource.dart';
import '../../data/repositories/supabase_supplier_finance_repository.dart';
import '../../domain/compute_financial_summary.dart';
import '../../domain/entities/payout_request.dart';
import '../../domain/entities/supplier_finance_settings.dart';
import '../../domain/entities/supplier_financial_summary.dart';
import '../../domain/repositories/supplier_finance_repository.dart';

final supplierFinanceDatasourceProvider =
    Provider<SupabaseSupplierFinanceDatasource>((ref) {
      return SupabaseSupplierFinanceDatasource(ref.watch(supabaseClientProvider));
    });

final supplierFinanceRepositoryProvider = Provider<SupplierFinanceRepository>((
  ref,
) {
  return SupabaseSupplierFinanceRepository(
    ref.watch(supplierFinanceDatasourceProvider),
  );
});

final payoutRequestsProvider =
    StreamProvider.family<List<PayoutRequest>, String>((ref, supplierId) {
      return ref
          .watch(supplierFinanceRepositoryProvider)
          .watchPayoutRequests(supplierId);
    });

final allPayoutRequestsProvider = StreamProvider<List<PayoutRequest>>((ref) {
  return ref.watch(supplierFinanceRepositoryProvider).watchAllPayoutRequests();
});

final financeSettingsProvider =
    FutureProvider.family<SupplierFinanceSettings, String>((ref, supplierId) {
      return ref.watch(supplierFinanceRepositoryProvider).getSettings(supplierId);
    });

/// Combines this supplier's own orders (via `supplierOrdersProvider` — the
/// same confidentiality-safe projection the "Commandes" tab uses, so this
/// never has to re-derive "which group is mine" itself), their commission
/// rate, and their payout history into one computed summary — a
/// presentation-layer join across the orders and finance features, the
/// same shape as `supplierCommentInboxProvider` (Lot 9) or `SupplierOrderView`.
final financialSummaryProvider =
    Provider.family<AsyncValue<SupplierFinancialSummary>, String>((
      ref,
      supplierId,
    ) {
      final ordersAsync = ref.watch(supplierOrdersProvider(supplierId));
      final settingsAsync = ref.watch(financeSettingsProvider(supplierId));
      final payoutsAsync = ref.watch(payoutRequestsProvider(supplierId));

      if (ordersAsync.isLoading || settingsAsync.isLoading || payoutsAsync.isLoading) {
        return const AsyncLoading();
      }
      if (ordersAsync.hasError) {
        return AsyncError(ordersAsync.error!, ordersAsync.stackTrace!);
      }
      if (settingsAsync.hasError) {
        return AsyncError(settingsAsync.error!, settingsAsync.stackTrace!);
      }
      if (payoutsAsync.hasError) {
        return AsyncError(payoutsAsync.error!, payoutsAsync.stackTrace!);
      }

      final groups = <OrderSupplierGroup>[
        for (final view in ordersAsync.value ?? const <SupplierOrderView>[])
          view.myGroup,
      ];

      return AsyncData(
        computeFinancialSummary(
          supplierGroups: groups,
          commissionRatePercent: settingsAsync.value!.commissionRatePercent,
          payoutRequests: payoutsAsync.value ?? const <PayoutRequest>[],
        ),
      );
    });

/// Platform-wide commission total across every tiers supplier's delivered
/// orders — admin only. **Known simplification**: uses
/// `AppConstants.defaultCommissionRatePercent` uniformly rather than each
/// supplier's own (possibly overridden) rate, since no screen in this app
/// lets a supplier's rate diverge from the default yet — see
/// `SUPPLIER_INTERFACE_PROGRESS.md`.
final platformCommissionSummaryProvider = Provider<AsyncValue<int>>((ref) {
  final ordersAsync = ref.watch(allOrdersProvider);
  if (ordersAsync.isLoading) return const AsyncLoading();
  if (ordersAsync.hasError) {
    return AsyncError(ordersAsync.error!, ordersAsync.stackTrace!);
  }

  final orders = ordersAsync.value ?? const <Order>[];
  final allGroups = <OrderSupplierGroup>[
    for (final order in orders) ...order.supplierGroups,
  ];

  final summary = computeFinancialSummary(
    supplierGroups: allGroups,
    commissionRatePercent: AppConstants.defaultCommissionRatePercent,
    payoutRequests: const <PayoutRequest>[],
  );
  return AsyncData(summary.commissionFcfa);
});
