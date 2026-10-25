import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;

part 'payout_request.freezed.dart';
part 'payout_request.g.dart';

enum PayoutStatus {
  requested,
  processing,
  paid,
  rejected;

  String get label => switch (this) {
    PayoutStatus.requested => 'Demandé',
    PayoutStatus.processing => 'En traitement',
    PayoutStatus.paid => 'Payé',
    PayoutStatus.rejected => 'Rejeté',
  };

  bool get isTerminal => this == PayoutStatus.paid || this == PayoutStatus.rejected;
}

/// A supplier's withdrawal request against their available balance (see
/// `SupplierFinancialSummary.availableFcfa`) — the only element of the
/// finance feature actually **stored**; the summary itself is always
/// computed fresh by the server from the money MTC actually received
/// (`supplier_ledger`, `0131`).
@freezed
class PayoutRequest with _$PayoutRequest {
  const factory PayoutRequest({
    required String id,
    required String supplierId,
    required int amountFcfa,
    required PayoutStatus status,
    required DateTime requestedAt,

    /// Reuses `MobileMoneyProvider` rather than a new payout-specific
    /// enum — same two operators, no reason to duplicate.
    required MobileMoneyProvider method,
    required String payoutDestination,
    DateTime? processedAt,
    String? rejectionReason,
  }) = _PayoutRequest;

  factory PayoutRequest.fromJson(Map<String, dynamic> json) =>
      _$PayoutRequestFromJson(json);
}
