import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/order_providers.dart';
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';

import '../../data/datasources/supabase_supplier_finance_datasource.dart';
import '../../data/repositories/supabase_supplier_finance_repository.dart';
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

/// Le grand livre de la boutique, lu chez le serveur (`fetch_my_finance_summary`,
/// `0131`) — la règle « qui a encaissé » n'existe qu'en base.
///
/// Relu chaque fois qu'une commande de la boutique ou un de ses retraits
/// change : ce sont les deux seules choses qui le font bouger. Le serveur
/// ne laisse lire que le propriétaire (et le staff, pour la boutique MTC).
final financialSummaryProvider =
    FutureProvider.family<SupplierFinancialSummary, String>((ref, supplierId) {
      ref.watch(supplierOrdersProvider(supplierId));
      ref.watch(payoutRequestsProvider(supplierId));
      return ref
          .watch(supplierFinanceRepositoryProvider)
          .fetchMyFinanceSummary();
    });

/// Le total des commissions de la plateforme — administrateurs seulement.
///
/// Compté par le serveur, boutique par boutique, avec le taux de chacune et
/// la même règle que les soldes. Il n'applique plus, comme avant, un taux
/// unique à toute commande livrée, y compris celles dont personne n'a
/// encore vu l'argent.
final platformCommissionSummaryProvider = FutureProvider<int>((ref) {
  ref.watch(allOrdersProvider);
  return ref
      .watch(supplierFinanceRepositoryProvider)
      .fetchPlatformCommissionFcfa();
});
