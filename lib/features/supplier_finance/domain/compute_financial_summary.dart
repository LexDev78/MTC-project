import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';

import 'entities/payout_request.dart';
import 'entities/supplier_financial_summary.dart';

/// Pure — no repository reads, same pattern as `delivery_pricing.dart`, so
/// the money math is testable without a `ProviderContainer`.
///
/// [supplierGroups] is every `OrderSupplierGroup` belonging to one supplier,
/// any status — filtering to `delivered` only is this function's job (not
/// the caller's), since "which orders count toward revenue" is exactly the
/// business rule worth having a dedicated test for.
SupplierFinancialSummary computeFinancialSummary({
  required List<OrderSupplierGroup> supplierGroups,
  required double commissionRatePercent,
  required List<PayoutRequest> payoutRequests,
}) {
  final grossFcfa = supplierGroups
      .where((g) => g.status == OrderStatus.delivered)
      // Never `deliveryFeeFcfa` — that's already 0 in `selfDelivery` mode
      // and, when MTC delivers, belongs to the platform's delivery
      // operation, not the supplier's own revenue.
      .fold<int>(0, (sum, g) => sum + g.subtotalFcfa);

  final commissionFcfa = (grossFcfa * commissionRatePercent / 100).round();
  final netFcfa = grossFcfa - commissionFcfa;

  final paidOutFcfa = payoutRequests
      .where((p) => p.status != PayoutStatus.rejected)
      .fold<int>(0, (sum, p) => sum + p.amountFcfa);

  return SupplierFinancialSummary(
    grossFcfa: grossFcfa,
    commissionFcfa: commissionFcfa,
    netFcfa: netFcfa,
    paidOutFcfa: paidOutFcfa,
    availableFcfa: netFcfa - paidOutFcfa,
  );
}
