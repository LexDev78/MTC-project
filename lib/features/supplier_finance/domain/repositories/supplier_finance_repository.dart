import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;

import '../entities/payout_request.dart';
import '../entities/supplier_finance_settings.dart';

abstract interface class SupplierFinanceRepository {
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
