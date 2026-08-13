import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_role.dart';

part 'app_user.freezed.dart';

/// Sealed union of the three account types. Modeled as one union (rather
/// than three unrelated classes) so role-based branching — router redirects,
/// shell selection — is exhaustive and compiler-checked via `switch`.
/// Fields shared by every variant (id, displayName, usernameOrPhone,
/// phoneNumber, createdAt) are exposed directly on [AppUser] by Freezed;
/// role-specific fields require pattern matching on the concrete subtype.
@freezed
sealed class AppUser with _$AppUser {
  const factory AppUser.client({
    required String id,
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required DateTime createdAt,
    String? defaultAddressId,
  }) = ClientUser;

  const factory AppUser.supplierTiers({
    required String id,
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required DateTime createdAt,
    required String businessName,
    required VerificationStatus verificationStatus,
    required String city,
    required double ratingAverage,
    required int ratingCount,
    required SupplierLegalType legalType,
  }) = SupplierTiersUser;

  const factory AppUser.supplierPrincipal({
    required String id,
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required DateTime createdAt,
    required StaffRole staffRole,
  }) = SupplierPrincipalUser;
}

extension AppUserRoleX on AppUser {
  UserRole get role => switch (this) {
    ClientUser() => UserRole.client,
    SupplierTiersUser() => UserRole.supplierTiers,
    SupplierPrincipalUser() => UserRole.supplierPrincipal,
  };
}

extension SupplierTiersUserOnboardingX on SupplierTiersUser {
  /// No KYC dossier has ever been submitted — the router forces this
  /// account into the onboarding wizard instead of the dashboard.
  bool get needsOnboarding =>
      verificationStatus == VerificationStatus.unverified;

  /// A dossier was submitted and rejected — the wizard stays reachable (to
  /// correct and resubmit) but isn't forced the way [needsOnboarding] is.
  bool get canReviseOnboarding =>
      verificationStatus == VerificationStatus.rejected;
}
