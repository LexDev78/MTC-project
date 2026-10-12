import '../entities/app_user.dart';
import '../entities/user_role.dart';

/// Auth contract. The in-memory implementation backs this today; a Firebase
/// Auth implementation can replace it later without touching any call site.
abstract interface class AuthRepository {
  /// Emits the current session's user, or `null` when signed out.
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser> login({
    required String usernameOrPhone,
    required String password,
  });

  Future<AppUser> signUpClient({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
  });

  Future<AppUser> signUpSupplierTiers({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String businessName,
    required String city,
    required SupplierLegalType legalType,
  });

  /// Inscription d'un livreur. Le compte est créé immédiatement mais sa
  /// fiche reste `pending` : c'est un agent MTC qui l'active, aucune course
  /// ne lui est proposée d'ici là (`0046_couriers_and_deliveries.sql`).
  Future<AppUser> signUpCourier({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String city,
    String? vehicleLabel,
  });

  Future<AppUser> signUpSupplierPrincipal({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required StaffRole staffRole,
  });

  Future<void> logout();

  /// Soft-deletes the signed-in account, then signs out — see
  /// `deactivate_account()` (`supabase/migrations/0036_account_deactivation.sql`)
  /// for exactly what this blocks (a supplier with unresolved orders/
  /// payouts) and what it never allows (a staff account deleting itself).
  Future<void> deleteAccount();

  /// Restores a previously persisted session (e.g. after an app restart).
  Future<void> restoreSession();

  /// Applies a staff KYC decision to the supplier's account. Called by
  /// `KycReviewController` alongside `SupplierRepository.updateVerificationStatus`
  /// — cross-repository orchestration lives in that controller, never here.
  Future<void> updateSupplierVerificationStatus({
    required String userId,
    required VerificationStatus status,
  });
}
