import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/notifications/domain/entities/app_notification.dart';
import 'package:mtc_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;
import 'package:mtc_app/features/orders/presentation/providers/supplier_order_providers.dart';
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../../domain/compute_financial_summary.dart';
import '../../domain/entities/payout_request.dart';
import '../providers/supplier_finance_providers.dart';

/// Drives payout requests for the operating supplier and staff review
/// decisions on any supplier's request — same controller for both, the way
/// `KycReviewController` covers both a fournisseur's submission and a
/// staff decision on it.
class SupplierFinanceController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Throws (surfaced as an error state) rather than silently clamping the
  /// amount if it exceeds the supplier's current available balance —
  /// requesting more than you have is a mistake worth reporting, not
  /// rounding down from.
  Future<bool> requestPayout({
    required int amountFcfa,
    required MobileMoneyProvider method,
    required String payoutDestination,
  }) async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return false;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (amountFcfa <= 0) {
        throw const ValidationException('Le montant doit être positif');
      }

      // Awaited fresh rather than read off `financialSummaryProvider`
      // directly — that derived provider only has a value once some
      // screen has already watched it, which isn't guaranteed here.
      final views = await ref.read(supplierOrdersProvider(supplierId).future);
      final settings = await ref.read(financeSettingsProvider(supplierId).future);
      final payouts = await ref.read(payoutRequestsProvider(supplierId).future);
      final summary = computeFinancialSummary(
        supplierGroups: [for (final v in views) v.myGroup],
        commissionRatePercent: settings.commissionRatePercent,
        payoutRequests: payouts,
      );
      if (amountFcfa > summary.availableFcfa) {
        throw const ValidationException(
          'Le montant dépasse votre solde disponible',
        );
      }

      await ref
          .read(supplierFinanceRepositoryProvider)
          .requestPayout(
            supplierId: supplierId,
            amountFcfa: amountFcfa,
            method: method,
            payoutDestination: payoutDestination,
          );
    });

    return !state.hasError;
  }

  /// Staff-only decision on a pending request — never gated by
  /// `operatingSupplierIdProvider` since an admin reviews every supplier's
  /// requests, not just their own storefront's.
  Future<bool> reviewPayout({
    required String payoutId,
    required PayoutStatus status,
    String? rejectionReason,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final updated = await ref
          .read(supplierFinanceRepositoryProvider)
          .updatePayoutStatus(
            payoutId: payoutId,
            status: status,
            rejectionReason: rejectionReason,
          );
      await ref
          .read(notificationRepositoryProvider)
          .add(
            userId: updated.supplierId,
            type: NotificationType.payoutDecision,
            title: 'Retrait ${status.label.toLowerCase()}',
            body: status == PayoutStatus.rejected && rejectionReason != null
                ? rejectionReason
                : '${updated.amountFcfa} FCFA',
          );
    });
    return !state.hasError;
  }
}

final supplierFinanceControllerProvider =
    AsyncNotifierProvider<SupplierFinanceController, void>(
      SupplierFinanceController.new,
    );
