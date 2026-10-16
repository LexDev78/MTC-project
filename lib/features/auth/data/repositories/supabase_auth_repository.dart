import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mtc_app/core/auth/pseudo_email.dart';
import 'package:mtc_app/core/error/exceptions.dart';
import 'package:mtc_app/features/suppliers/domain/entities/supplier_profile.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/supabase_auth_datasource.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._datasource);

  final SupabaseAuthDatasource _datasource;

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    // Seed with whatever session already exists. `onAuthStateChange` only
    // replays an initial event when the client went through
    // `supabase_flutter`'s `Supabase.initialize()` (its `SupabaseAuth`
    // wrapper explicitly fires `AuthChangeEvent.initialSession` at
    // startup) — a bare `SupabaseClient` (e.g. in tests, see
    // `test/support/supabase_test_harness.dart`) never emits anything on
    // its own until an explicit sign-in/out happens, which would leave
    // `currentUserProvider` — and the splash screen waiting on it — stuck
    // on `AsyncLoading` forever. Checking `currentSession` directly makes
    // this correct regardless of how the client was constructed.
    final initialUserId = _datasource.currentSession?.user.id;
    yield initialUserId == null ? null : await _hydrateOrSignOutIfDeleted(initialUserId);

    await for (final state in _datasource.onAuthStateChange()) {
      final userId = state.session?.user.id;
      yield userId == null ? null : await _hydrateOrSignOutIfDeleted(userId);
    }
  }

  /// Fires on every `onAuthStateChange` event, including a token refresh —
  /// so a session that was already open on this or another device gets
  /// caught the same way a fresh login does, without needing its own
  /// separate check. A deleted account is signed out here rather than
  /// surfaced as a stream error, so the app just sees `null` and redirects
  /// to the login screen the same way a normal logout does.
  Future<AppUser?> _hydrateOrSignOutIfDeleted(String userId) async {
    try {
      return await _hydrateAppUser(userId);
    } on AccountDeletedException {
      await _datasource.signOut();
      return null;
    }
  }

  @override
  Future<AppUser> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    final AuthResponse response;
    try {
      response = await _datasource.signInWithPassword(
        email: pseudoEmail(usernameOrPhone),
        password: password,
      );
    } on AuthException {
      throw const InvalidCredentialsException();
    }
    final userId = response.session?.user.id;
    if (userId == null) throw const InvalidCredentialsException();
    return _hydrateAppUser(userId);
  }

  @override
  Future<AppUser> signUpClient({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
  }) async {
    final userId = await _signUp(
      usernameOrPhone: usernameOrPhone,
      password: password,
      data: {
        'role': 'client',
        'username_or_phone': usernameOrPhone,
        'display_name': displayName,
        'phone_number': phoneNumber,
      },
    );
    return _hydrateAppUser(userId);
  }

  @override
  Future<AppUser> signUpSupplierTiers({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String businessName,
    required String city,
    required SupplierLegalType legalType,
  }) async {
    final userId = await _signUp(
      usernameOrPhone: usernameOrPhone,
      password: password,
      data: {
        'role': 'supplier_tiers',
        'username_or_phone': usernameOrPhone,
        'display_name': displayName,
        'phone_number': phoneNumber,
        'business_name': businessName,
        'city': city,
        'legal_type': legalType.name,
      },
    );
    return _hydrateAppUser(userId);
  }

  @override
  Future<AppUser> signUpCourier({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required String city,
    String? vehicleLabel,
  }) async {
    final userId = await _signUp(
      usernameOrPhone: usernameOrPhone,
      password: password,
      data: {
        'role': 'livreur',
        'username_or_phone': usernameOrPhone,
        'display_name': displayName,
        'phone_number': phoneNumber,
        'city': city,
        if (vehicleLabel != null && vehicleLabel.isNotEmpty)
          'vehicle_label': vehicleLabel,
      },
    );
    return _hydrateAppUser(userId);
  }

  @override
  Future<AppUser> signUpSupplierPrincipal({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required StaffRole staffRole,
  }) async {
    final userId = await _signUp(
      usernameOrPhone: usernameOrPhone,
      password: password,
      data: {
        'role': 'supplier_principal',
        'username_or_phone': usernameOrPhone,
        'display_name': displayName,
        'phone_number': phoneNumber,
        'staff_role': staffRole.name,
      },
    );
    return _hydrateAppUser(userId);
  }

  @override
  Future<void> logout() => _datasource.signOut();

  @override
  Future<void> deleteAccount() async {
    try {
      await _datasource.deactivateAccount();
    } on PostgrestException catch (e) {
      throw ValidationException(e.message);
    }
    await _datasource.signOut();
  }

  /// A no-op: `supabase_flutter` persists/restores/refreshes the session
  /// itself as part of `Supabase.initialize()` (awaited before `runApp` in
  /// `bootstrap.dart`), and `onAuthStateChange` always replays the current
  /// state to a new listener — by the time this could run, there is nothing
  /// left to restore.
  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> updateSupplierVerificationStatus({
    required String userId,
    required VerificationStatus status,
  }) {
    return _datasource.updateSupplierVerificationStatus(
      supplierId: userId,
      status: status.name,
    );
  }

  Future<String> _signUp({
    required String usernameOrPhone,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final AuthResponse response;
    try {
      response = await _datasource.signUp(
        email: pseudoEmail(usernameOrPhone),
        password: password,
        data: data,
      );
    } on AuthException {
      throw const UsernameAlreadyTakenException();
    }
    final userId = response.user?.id;
    if (userId == null) throw const UsernameAlreadyTakenException();
    return userId;
  }

  /// `AppUser` is a sealed union with no direct table of its own — it's
  /// assembled here from `profiles` (+ `suppliers` for a tiers account),
  /// the same "reconstructed by joining at read time" shape the plan uses
  /// throughout instead of duplicating fields that could drift apart.
  Future<AppUser> _hydrateAppUser(String userId) async {
    final profileRow = await _datasource.fetchProfileRow(userId);
    if (profileRow['deleted_at'] != null) throw const AccountDeletedException();
    final role = profileRow['role'] as String;
    final displayName = profileRow['display_name'] as String;
    final usernameOrPhone = profileRow['username_or_phone'] as String;
    final phoneNumber = profileRow['phone_number'] as String;
    final createdAt = DateTime.parse(profileRow['created_at'] as String);

    switch (role) {
      case 'client':
        return AppUser.client(
          id: userId,
          displayName: displayName,
          usernameOrPhone: usernameOrPhone,
          phoneNumber: phoneNumber,
          createdAt: createdAt,
          defaultAddressId: profileRow['default_address_id'] as String?,
        );
      case 'supplier_tiers':
        // Deux comptes portent ce rôle : celui qui possède la boutique, et
        // celui que le patron a créé pour l'aider (`0093`). Ce qui les
        // distingue est l'existence d'une ligne `suppliers` à son nom —
        // le collaborateur n'en a pas, et c'est voulu : lui en donner une
        // lui ouvrirait une boutique vide dont personne ne veut.
        final collaboration = await _datasource.fetchCollaborationRow(userId);
        final shopId = collaboration?['supplier_id'] as String? ?? userId;
        final supplierRow = await _datasource.fetchSupplierRow(shopId);
        final supplier = SupplierProfile.fromJson(supplierRow);
        return AppUser.supplierTiers(
          id: userId,
          operatesSupplierId: collaboration == null ? null : shopId,
          mustChangePassword:
              profileRow['must_change_password'] as bool? ?? false,
          permissions: [
            for (final p in (collaboration?['permissions'] as List? ?? const []))
              p as String,
          ],
          displayName: displayName,
          usernameOrPhone: usernameOrPhone,
          phoneNumber: phoneNumber,
          createdAt: createdAt,
          businessName: supplier.businessName,
          verificationStatus: supplier.verificationStatus!,
          city: supplier.city,
          ratingAverage: supplier.ratingAverage,
          ratingCount: supplier.ratingCount,
          legalType: supplier.legalType!,
        );
      case 'livreur':
        final courierRow = await _datasource.fetchCourierRow(userId);
        return AppUser.courier(
          id: userId,
          displayName: displayName,
          usernameOrPhone: usernameOrPhone,
          phoneNumber: phoneNumber,
          createdAt: createdAt,
          courierStatus: CourierStatus.values.byName(
            courierRow['status'] as String,
          ),
          city: courierRow['city'] as String,
          isOnline: courierRow['is_online'] as bool? ?? false,
          vehicleLabel: courierRow['vehicle_label'] as String?,
          documentsSubmittedAt: courierRow['documents_submitted_at'] == null
              ? null
              : DateTime.parse(courierRow['documents_submitted_at'] as String),
        );
      case 'supplier_principal':
        return AppUser.supplierPrincipal(
          id: userId,
          displayName: displayName,
          usernameOrPhone: usernameOrPhone,
          phoneNumber: phoneNumber,
          createdAt: createdAt,
          staffRole: StaffRole.values.byName(profileRow['staff_role'] as String),
        );
      default:
        throw StateError('Rôle de profil inconnu : $role');
    }
  }
}
