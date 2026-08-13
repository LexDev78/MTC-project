import 'package:flutter_test/flutter_test.dart';

import 'package:mtc_app/features/orders/domain/entities/order.dart';
import 'package:mtc_app/features/orders/domain/entities/order_status.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';
import 'package:mtc_app/features/supplier_finance/domain/compute_financial_summary.dart';
import 'package:mtc_app/features/supplier_finance/domain/entities/payout_request.dart';

OrderSupplierGroup _group({
  required int subtotalFcfa,
  OrderStatus status = OrderStatus.delivered,
  int deliveryFeeFcfa = 0,
}) {
  return OrderSupplierGroup(
    id: 'group-$subtotalFcfa-${status.name}',
    supplierId: 'supplier-1',
    supplierName: 'Test Supplier',
    items: const [],
    deliveryMode: DeliveryMode.selfDelivery,
    deliveryFeeFcfa: deliveryFeeFcfa,
    subtotalFcfa: subtotalFcfa,
    status: status,
  );
}

PayoutRequest _payout({required int amountFcfa, required PayoutStatus status}) {
  return PayoutRequest(
    id: 'payout-$amountFcfa-${status.name}',
    supplierId: 'supplier-1',
    amountFcfa: amountFcfa,
    status: status,
    requestedAt: DateTime(2026, 1, 1),
    method: MobileMoneyProvider.orangeMoney,
    payoutDestination: '+22370000000',
  );
}

void main() {
  test(
    'only delivered groups count toward gross — pending/cancelled groups '
    'are ignored',
    () {
      final summary = computeFinancialSummary(
        supplierGroups: [
          _group(subtotalFcfa: 10000),
          _group(subtotalFcfa: 5000, status: OrderStatus.pending),
          _group(subtotalFcfa: 7000, status: OrderStatus.cancelled),
        ],
        commissionRatePercent: 10,
        payoutRequests: const [],
      );

      expect(summary.grossFcfa, 10000);
    },
  );

  test('deliveryFeeFcfa never counts toward gross, even when non-zero', () {
    final summary = computeFinancialSummary(
      supplierGroups: [_group(subtotalFcfa: 10000, deliveryFeeFcfa: 1500)],
      commissionRatePercent: 10,
      payoutRequests: const [],
    );

    expect(summary.grossFcfa, 10000);
  });

  test('commission and net are computed from the rate, rounded to the '
      'nearest FCFA', () {
    final summary = computeFinancialSummary(
      supplierGroups: [_group(subtotalFcfa: 25000)],
      commissionRatePercent: 10,
      payoutRequests: const [],
    );

    expect(summary.commissionFcfa, 2500);
    expect(summary.netFcfa, 22500);
  });

  test('a 0% commission rate (MTC direct sales) leaves net equal to gross', () {
    final summary = computeFinancialSummary(
      supplierGroups: [_group(subtotalFcfa: 25000)],
      commissionRatePercent: 0,
      payoutRequests: const [],
    );

    expect(summary.commissionFcfa, 0);
    expect(summary.netFcfa, summary.grossFcfa);
  });

  test(
    'paidOutFcfa sums every non-rejected payout, and availableFcfa '
    "subtracts it from net — a rejected payout doesn't reserve funds",
    () {
      final summary = computeFinancialSummary(
        supplierGroups: [_group(subtotalFcfa: 25000)],
        commissionRatePercent: 10,
        payoutRequests: [
          _payout(amountFcfa: 5000, status: PayoutStatus.paid),
          _payout(amountFcfa: 3000, status: PayoutStatus.processing),
          _payout(amountFcfa: 2000, status: PayoutStatus.requested),
          _payout(amountFcfa: 9000, status: PayoutStatus.rejected),
        ],
      );

      // net = 22500; paidOut = 5000 + 3000 + 2000 = 10000 (rejected excluded)
      expect(summary.netFcfa, 22500);
      expect(summary.paidOutFcfa, 10000);
      expect(summary.availableFcfa, 12500);
    },
  );

  test('no delivered orders and no payouts yields an all-zero summary', () {
    final summary = computeFinancialSummary(
      supplierGroups: const [],
      commissionRatePercent: 10,
      payoutRequests: const [],
    );

    expect(summary.grossFcfa, 0);
    expect(summary.commissionFcfa, 0);
    expect(summary.netFcfa, 0);
    expect(summary.paidOutFcfa, 0);
    expect(summary.availableFcfa, 0);
  });
}
