import 'package:mtc_app/features/auth/domain/entities/user_role.dart'
    show SupplierLegalType, VerificationStatus;
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

import '../entities/supplier_profile.dart';

abstract interface class SupplierRepository {
  Stream<List<SupplierProfile>> watchByType(SupplierType type);

  Future<SupplierProfile> getById(String id);

  Stream<List<SupplierProfile>> watchTopRated({int limit = 5});

  /// Creates the public storefront profile for a newly-registered
  /// "fournisseur tiers" account. Called right after `AuthRepository`
  /// creates the `AppUser`, from `AuthController` — `data/` repositories
  /// never call each other directly (see `ReviewController` for the same
  /// cross-repository orchestration pattern).
  Future<SupplierProfile> createProfile({
    required String id,
    required String businessName,
    required SupplierType supplierType,
    required String city,
    required SupplierLegalType legalType,
  });

  /// Folds a new review's [stars] into the supplier's running rating
  /// average (`(oldAverage * oldCount + stars) / (oldCount + 1)`) and
  /// returns the updated aggregate, so callers can propagate it to
  /// wherever else a supplier's rating is denormalized (e.g. `Product`).
  Future<({double average, int count})> recordReview({
    required String supplierId,
    required int stars,
  });

  /// Applies a staff KYC decision to the supplier's public storefront card.
  /// Called by `KycReviewController` alongside
  /// `AuthRepository.updateSupplierVerificationStatus` — cross-repository
  /// orchestration lives in that controller, never here.
  Future<void> updateVerificationStatus({
    required String supplierId,
    required VerificationStatus status,
  });

  /// Adjusts the storefront card's product count by [delta] — called by
  /// `SupplierProductController` (+1 creating a listing, -1 archiving one),
  /// never derived by counting `Product` rows directly (that would be a
  /// cross-repository read from within `suppliers/data`).
  Future<void> adjustProductCount({
    required String supplierId,
    required int delta,
  });
}
