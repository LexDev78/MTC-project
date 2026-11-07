import 'package:freezed_annotation/freezed_annotation.dart';

part 'supplier_finance_settings.freezed.dart';
part 'supplier_finance_settings.g.dart';

/// Per-supplier commission rate — defaults to
/// `AppConstants.defaultCommissionRatePercent` (see
/// `SupplierFinanceRepository.getSettings`) until a staff member overrides
/// it with `updateSettings`.
@freezed
class SupplierFinanceSettings with _$SupplierFinanceSettings {
  const factory SupplierFinanceSettings({
    required String supplierId,
    required double commissionRatePercent,
  }) = _SupplierFinanceSettings;

  factory SupplierFinanceSettings.fromJson(Map<String, dynamic> json) =>
      _$SupplierFinanceSettingsFromJson(json);
}
