abstract final class AppConstants {
  static const String appName = 'Mali Trade Connect';
  static const String currencySuffix = 'FCFA';
  static const int defaultPageSize = 20;

  /// Shared password for every seeded demo account (mock backend only).
  static const String demoPassword = 'password123';

  /// Version tag of the personal-data processing policy shown during
  /// individual supplier ("fournisseur libre") KYC — recorded on
  /// `DataProcessingConsent.policyVersion` so a later wording change is
  /// auditable (loi malienne n°2013-015 / APDP Mali).
  static const String currentDataProcessingPolicyVersion = 'v1';
}
