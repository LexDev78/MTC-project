import 'package:freezed_annotation/freezed_annotation.dart';

part 'supplier_financial_summary.freezed.dart';

/// Never stored — always recomputed from delivered orders + payout history
/// (see `computeFinancialSummary`), the same way `SupplierOrderView` is a
/// presentation-layer projection rather than a persisted record.
@freezed
class SupplierFinancialSummary with _$SupplierFinancialSummary {
  const factory SupplierFinancialSummary({
    required int grossFcfa,
    required int commissionFcfa,
    required int netFcfa,

    /// Sum of every payout not `rejected` (`requested`/`processing`/`paid`
    /// all reserve funds against the balance — only a rejection releases
    /// them back).
    required int paidOutFcfa,

    /// `netFcfa - paidOutFcfa` — what's left to request as a new payout.
    required int availableFcfa,
  }) = _SupplierFinancialSummary;
}
