import 'package:mtc_app/features/orders/domain/entities/payment.dart' show MobileMoneyProvider;

import '../../domain/entities/payout_request.dart';
import '../../domain/entities/supplier_finance_settings.dart';
import '../../domain/repositories/supplier_finance_repository.dart';
import '../datasources/in_memory_supplier_finance_datasource.dart';

class InMemorySupplierFinanceRepository implements SupplierFinanceRepository {
  InMemorySupplierFinanceRepository(this._datasource);

  final InMemorySupplierFinanceDatasource _datasource;

  @override
  Stream<List<PayoutRequest>> watchPayoutRequests(String supplierId) {
    return _datasource.watchAll().map(
      (payouts) =>
          payouts.where((p) => p.supplierId == supplierId).toList()
            ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt)),
    );
  }

  @override
  Stream<List<PayoutRequest>> watchAllPayoutRequests() {
    return _datasource.watchAll().map(
      (payouts) => [...payouts]
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt)),
    );
  }

  @override
  Future<PayoutRequest> requestPayout({
    required String supplierId,
    required int amountFcfa,
    required MobileMoneyProvider method,
    required String payoutDestination,
  }) async {
    return _datasource.requestPayout(
      supplierId: supplierId,
      amountFcfa: amountFcfa,
      method: method,
      payoutDestination: payoutDestination,
    );
  }

  @override
  Future<PayoutRequest> updatePayoutStatus({
    required String payoutId,
    required PayoutStatus status,
    String? rejectionReason,
  }) async {
    return _datasource.updatePayoutStatus(
      payoutId: payoutId,
      status: status,
      rejectionReason: rejectionReason,
    );
  }

  @override
  Future<SupplierFinanceSettings> getSettings(String supplierId) async {
    return _datasource.getSettings(supplierId);
  }

  @override
  Future<void> updateSettings({
    required String supplierId,
    required double commissionRatePercent,
  }) async {
    _datasource.updateSettings(supplierId, commissionRatePercent);
  }
}
