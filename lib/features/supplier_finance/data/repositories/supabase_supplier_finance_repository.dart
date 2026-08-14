import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/constants/app_constants.dart';
import 'package:mtc_app/core/error/exceptions.dart';

import '../../../orders/domain/entities/payment.dart';
import '../../domain/entities/payout_request.dart';
import '../../domain/entities/supplier_finance_settings.dart';
import '../../domain/repositories/supplier_finance_repository.dart';
import '../datasources/supabase_supplier_finance_datasource.dart';

class SupabaseSupplierFinanceRepository implements SupplierFinanceRepository {
  SupabaseSupplierFinanceRepository(this._datasource);

  final SupabaseSupplierFinanceDatasource _datasource;

  @override
  Stream<List<PayoutRequest>> watchPayoutRequests(String supplierId) {
    return _datasource
        .watchPayoutRequests(supplierId)
        .map((rows) => rows.map(PayoutRequest.fromJson).toList());
  }

  @override
  Stream<List<PayoutRequest>> watchAllPayoutRequests() {
    return _datasource
        .watchAllPayoutRequests()
        .map((rows) => rows.map(PayoutRequest.fromJson).toList());
  }

  @override
  Future<PayoutRequest> requestPayout({
    required String supplierId,
    required int amountFcfa,
    required MobileMoneyProvider method,
    required String payoutDestination,
  }) async {
    final row = await _datasource.requestPayout({
      'supplier_id': supplierId,
      'amount_fcfa': amountFcfa,
      'method': _mobileMoneyProviderToDb(method),
      'payout_destination': payoutDestination,
    });
    return PayoutRequest.fromJson(row);
  }

  @override
  Future<PayoutRequest> updatePayoutStatus({
    required String payoutId,
    required PayoutStatus status,
    String? rejectionReason,
  }) async {
    final Map<String, dynamic> row;
    try {
      row = await _datasource.updatePayoutStatus(
        payoutId: payoutId,
        status: status.name,
        rejectionReason: rejectionReason,
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('Transition invalide')) {
        throw ValidationException(e.message);
      }
      rethrow;
    }
    return PayoutRequest.fromJson(row);
  }

  @override
  Future<SupplierFinanceSettings> getSettings(String supplierId) async {
    final row = await _datasource.getSettings(supplierId);
    if (row == null) {
      return SupplierFinanceSettings(
        supplierId: supplierId,
        commissionRatePercent: AppConstants.defaultCommissionRatePercent,
      );
    }
    return SupplierFinanceSettings.fromJson(row);
  }

  @override
  Future<void> updateSettings({
    required String supplierId,
    required double commissionRatePercent,
  }) {
    return _datasource.updateSettings(
      supplierId: supplierId,
      commissionRatePercent: commissionRatePercent,
    );
  }
}

String _mobileMoneyProviderToDb(MobileMoneyProvider provider) => switch (provider) {
  MobileMoneyProvider.orangeMoney => 'orange_money',
  MobileMoneyProvider.moovMoney => 'moov_money',
};
