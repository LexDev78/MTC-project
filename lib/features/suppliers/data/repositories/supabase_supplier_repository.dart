import '../../domain/entities/supplier_collaborator.dart';
import '../../domain/entities/supplier_dashboard_stats.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/supabase_supplier_datasource.dart';

class SupabaseSupplierRepository implements SupplierRepository {
  SupabaseSupplierRepository(this._datasource);

  final SupabaseSupplierDatasource _datasource;

  @override
  Stream<List<SupplierProfile>> watchByType(SupplierType type) {
    return _datasource
        .watchByType(type.name)
        .map((rows) => rows.map(SupplierProfile.fromJson).toList());
  }

  @override
  Future<SupplierProfile> getById(String id) async {
    return SupplierProfile.fromJson(await _datasource.getById(id));
  }

  @override
  Stream<List<SupplierProfile>> watchTopRated({int limit = 5}) {
    return _datasource
        .watchTopRated(limit: limit)
        .map((rows) => rows.map(SupplierProfile.fromJson).toList());
  }

  @override
  Future<List<SupplierProfile>> fetchListed() async {
    final rows = await _datasource.fetchListed();
    return rows.map(SupplierProfile.fromJson).toList();
  }

  /// Kept for interface completeness — `AuthController.signUpSupplierTiers`
  /// no longer calls this (the `suppliers` row is created atomically by
  /// `handle_new_user()`, see `supabase/migrations/0001_initial_schema.sql`).
  /// Nothing else in the app calls it today.
  @override
  Future<SupplierProfile> createProfile({
    required String id,
    required String businessName,
    required SupplierType supplierType,
    required String city,
    required SupplierLegalType legalType,
  }) async {
    final row = await _datasource.add({
      'id': id,
      'business_name': businessName,
      'supplier_type': supplierType.name,
      'city': city,
      'rating_average': 0,
      'rating_count': 0,
      'product_count': 0,
      'verification_status': VerificationStatus.unverified.name,
      'legal_type': legalType.name,
    });
    return SupplierProfile.fromJson(row);
  }

  @override
  Future<({double average, int count})> recordReview({
    required String supplierId,
    required int stars,
  }) {
    return _datasource.recordReview(supplierId: supplierId, stars: stars);
  }

  @override
  Future<void> updateVerificationStatus({
    required String supplierId,
    required VerificationStatus status,
  }) {
    return _datasource.updateVerificationStatus(supplierId, status.name);
  }

  @override
  Future<void> adjustProductCount({
    required String supplierId,
    required int delta,
  }) {
    return _datasource.adjustProductCount(supplierId, delta);
  }

  @override
  Future<void> updateStorefront({
    required String supplierId,
    required String businessName,
    required String? description,
    required String? bannerUrl,
    required List<String> publicPhoneNumbers,
    required String? openingHoursLabel,
  }) {
    return _datasource.updateStorefront(
      supplierId: supplierId,
      fields: {
        'business_name': businessName,
        'description': description,
        'banner_url': bannerUrl,
        'public_phone_numbers': publicPhoneNumbers,
        'opening_hours_label': openingHoursLabel,
      },
    );
  }

  @override
  Future<void> updateLocation({
    required String supplierId,
    required String? fullAddress,
    required double? addressLatitude,
    required double? addressLongitude,
    required List<String> deliveryZones,
  }) {
    return _datasource.updateStorefront(
      supplierId: supplierId,
      fields: {
        'full_address': fullAddress,
        'address_latitude': addressLatitude,
        'address_longitude': addressLongitude,
        'delivery_zones': deliveryZones,
      },
    );
  }

  @override
  Future<SupplierDashboardStats> fetchDashboardStats() async {
    return SupplierDashboardStats.fromRow(
      await _datasource.fetchDashboardStats(),
    );
  }

  @override
  Future<List<SupplierCollaborator>> fetchCollaborators() async {
    final rows = await _datasource.fetchCollaborators();
    return [for (final row in rows) SupplierCollaborator.fromRow(row)];
  }

  @override
  Future<({String userId, String temporaryPassword})> createCollaborator({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required Set<String> permissions,
  }) => _datasource.createCollaborator(
    displayName: displayName,
    usernameOrPhone: usernameOrPhone,
    phoneNumber: phoneNumber,
    permissions: permissions,
  );

  @override
  Future<void> setCollaboratorPermissions({
    required String userId,
    required Set<String> permissions,
  }) => _datasource.setCollaboratorPermissions(
    userId: userId,
    permissions: permissions,
  );

  @override
  Future<void> removeCollaborator(String userId) =>
      _datasource.removeCollaborator(userId);

  @override
  Future<void> reactivateCollaborator(String userId) =>
      _datasource.reactivateCollaborator(userId);

  @override
  Future<void> setOpen({required String supplierId, required bool isOpen}) {
    return _datasource.setOpen(supplierId, isOpen);
  }
}
