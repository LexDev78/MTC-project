import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:mtc_app/features/auth/domain/entities/user_role.dart'
    show VerificationStatus, SupplierLegalType;
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

part 'supplier_profile.freezed.dart';
part 'supplier_profile.g.dart';

/// Public-facing supplier entity — distinct from `AppUser`, which is "who is
/// logged in". A client browsing the catalog only ever needs this, never
/// the account/auth identity.
@freezed
class SupplierProfile with _$SupplierProfile {
  const factory SupplierProfile({
    required String id,
    required String businessName,
    required SupplierType supplierType,
    required String city,
    required double ratingAverage,
    required int ratingCount,
    required int productCount,
    VerificationStatus? verificationStatus,
    String? avatarUrl,
    // Null for `SupplierType.principal` (MTC itself has no legal form to
    // register) — only ever set for `SupplierType.tiers`.
    SupplierLegalType? legalType,

    // Extended storefront fields (Lot 11) — edited from
    // `SupplierAccountController.updateStorefront`, shown on the public
    // `SupplierProfileScreen`.
    String? description,
    String? bannerUrl,
    String? fullAddress,

    /// Derived from `city` via `MalianCity` (same lookup
    /// `ManageAddressesScreen` uses for a client address) rather than typed
    /// in by hand — no map picker in this app, and every seeded city
    /// already has known coordinates. Usable with `GeoDistance`.
    double? addressLatitude,
    double? addressLongitude,
    @Default(<String>[]) List<String> publicPhoneNumbers,
    @Default(<String>[]) List<String> deliveryZones,
    String? openingHoursLabel,
    @Default(true) bool isOpen,
  }) = _SupplierProfile;

  factory SupplierProfile.fromJson(Map<String, dynamic> json) =>
      _$SupplierProfileFromJson(json);
}
