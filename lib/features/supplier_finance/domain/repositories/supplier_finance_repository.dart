import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;

import '../entities/payout_request.dart';
import '../entities/supplier_finance_settings.dart';
import '../entities/supplier_financial_summary.dart';

abstract interface class SupplierFinanceRepository {
  /// Le grand livre de la boutique que l'on opère, calculé par le serveur
  /// (`0131`) : ce que MTC a encaissé, ce que la boutique a encaissé
  /// elle-même, et ce qui reste à retirer. Réservé au propriétaire.
  Future<SupplierFinancialSummary> fetchMyFinanceSummary();

  /// Le total des commissions de la plateforme, boutique par boutique,
  /// avec la même règle — administrateurs seulement.
  Future<int> fetchPlatformCommissionFcfa();

  Stream<List<PayoutRequest>> watchPayoutRequests(String supplierId);

  /// Every payout request across every supplier — admin only, cross-
  /// supplier (see `PayoutReviewQueueScreen`).
  Stream<List<PayoutRequest>> watchAllPayoutRequests();

  Future<PayoutRequest> requestPayout({
    required String supplierId,
    required int amountFcfa,
    required MobileMoneyProvider method,
    required String payoutDestination,
  });

  /// A staff decision on a pending payout — throws `ValidationException`
  /// if [status] isn't a valid move from the request's current status
  /// (`requested` → `processing`/`rejected`, `processing` →
  /// `paid`/`rejected`; `paid`/`rejected` are terminal). Returns the
  /// updated record so the caller (see `SupplierFinanceController.reviewPayout`)
  /// can notify the right supplier without a second read.
  Future<PayoutRequest> updatePayoutStatus({
    required String payoutId,
    required PayoutStatus status,
    String? rejectionReason,
  });

  /// Defaults to `AppConstants.defaultCommissionRatePercent` the first time
  /// a supplier's settings are read, before any `updateSettings` call.
  Future<SupplierFinanceSettings> getSettings(String supplierId);

  Future<void> updateSettings({
    required String supplierId,
    required double commissionRatePercent,
  });
}
