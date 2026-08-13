import 'dart:async';

import 'package:mtc_app/core/constants/app_constants.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/core/mock_data/demo_ids.dart';
import 'package:mtc_app/core/utils/id_generator.dart';
import 'package:mtc_app/features/orders/domain/entities/payment.dart';

import '../../domain/entities/payout_request.dart';
import '../../domain/entities/supplier_finance_settings.dart';

class InMemorySupplierFinanceDatasource {
  InMemorySupplierFinanceDatasource() {
    _payouts.addAll(_seed());
  }

  final List<PayoutRequest> _payouts = [];
  final Map<String, SupplierFinanceSettings> _settings = {};
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<List<PayoutRequest>> watchAll() {
    return Stream<void>.multi((controller) {
      controller.add(null);
      final subscription = _changesController.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true).map((_) => List<PayoutRequest>.unmodifiable(_payouts));
  }

  PayoutRequest requestPayout({
    required String supplierId,
    required int amountFcfa,
    required MobileMoneyProvider method,
    required String payoutDestination,
  }) {
    final payout = PayoutRequest(
      id: IdGenerator.next(),
      supplierId: supplierId,
      amountFcfa: amountFcfa,
      status: PayoutStatus.requested,
      requestedAt: DateTime.now(),
      method: method,
      payoutDestination: payoutDestination,
    );
    _payouts.add(payout);
    _changesController.add(null);
    return payout;
  }

  PayoutRequest updatePayoutStatus({
    required String payoutId,
    required PayoutStatus status,
    String? rejectionReason,
  }) {
    final index = _payouts.indexWhere((p) => p.id == payoutId);
    if (index == -1) {
      throw NotFoundException('Retrait introuvable : $payoutId');
    }
    final current = _payouts[index];
    if (!_isValidTransition(current.status, status)) {
      throw ValidationException(
        'Transition invalide : ${current.status.label} → ${status.label}',
      );
    }
    final updated = current.copyWith(
      status: status,
      processedAt: DateTime.now(),
      rejectionReason: status == PayoutStatus.rejected ? rejectionReason : null,
    );
    _payouts[index] = updated;
    _changesController.add(null);
    return updated;
  }

  bool _isValidTransition(PayoutStatus from, PayoutStatus to) {
    return switch (from) {
      PayoutStatus.requested =>
        to == PayoutStatus.processing || to == PayoutStatus.rejected,
      PayoutStatus.processing =>
        to == PayoutStatus.paid || to == PayoutStatus.rejected,
      PayoutStatus.paid || PayoutStatus.rejected => false,
    };
  }

  SupplierFinanceSettings getSettings(String supplierId) {
    return _settings[supplierId] ??
        SupplierFinanceSettings(
          supplierId: supplierId,
          commissionRatePercent: AppConstants.defaultCommissionRatePercent,
        );
  }

  void updateSettings(String supplierId, double commissionRatePercent) {
    _settings[supplierId] = SupplierFinanceSettings(
      supplierId: supplierId,
      commissionRatePercent: commissionRatePercent,
    );
    _changesController.add(null);
  }

  /// One already-decided payout for the seeded delivered order
  /// (`order-awa-delivered`, Bogolan Bamako, `gross = 25000`) so the
  /// finance screen has something realistic to show without a fresh
  /// request first.
  List<PayoutRequest> _seed() {
    final now = DateTime.now();
    return [
      PayoutRequest(
        id: 'payout-bogolan-1',
        supplierId: DemoIds.supplierBogolanBamako,
        amountFcfa: 10000,
        status: PayoutStatus.paid,
        requestedAt: now.subtract(const Duration(days: 4)),
        processedAt: now.subtract(const Duration(days: 3)),
        method: MobileMoneyProvider.orangeMoney,
        payoutDestination: '+22370000010',
      ),
    ];
  }
}
