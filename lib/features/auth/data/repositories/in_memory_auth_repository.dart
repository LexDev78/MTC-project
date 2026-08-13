import 'package:shared_preferences/shared_preferences.dart';

import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/in_memory_auth_datasource.dart';

class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository(this._datasource, this._prefs);

  final InMemoryAuthDatasource _datasource;
  final SharedPreferences _prefs;

  static const String _sessionKeyPref = 'mtc_session_key';

  @override
  Stream<AppUser?> watchCurrentUser() => _datasource.watchCurrentUser();

  @override
  Future<AppUser> login({
    required String usernameOrPhone,
    required String password,
  }) async {
    final user = _datasource.login(usernameOrPhone, password);
    await _persistSessionKey(usernameOrPhone);
    return user;
  }

  @override
  Future<AppUser> signUpClient({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
  }) async {
    final user = AppUser.client(
      id: IdGenerator.next(),
      displayName: displayName,
      usernameOrPhone: usernameOrPhone,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
    );
    final created = _datasource.createAccount(user, usernameOrPhone, password);
    await _persistSessionKey(usernameOrPhone);
    return created;
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
    final user = AppUser.supplierTiers(
      id: IdGenerator.next(),
      displayName: displayName,
      usernameOrPhone: usernameOrPhone,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
      businessName: businessName,
      // No KYC dossier has been submitted yet at this point — submitting it
      // (supplier_onboarding, a later iteration) is what moves this to
      // `pending`.
      verificationStatus: VerificationStatus.unverified,
      city: city,
      ratingAverage: 0,
      ratingCount: 0,
      legalType: legalType,
    );
    final created = _datasource.createAccount(user, usernameOrPhone, password);
    await _persistSessionKey(usernameOrPhone);
    return created;
  }

  @override
  Future<AppUser> signUpSupplierPrincipal({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required String password,
    required StaffRole staffRole,
  }) async {
    final user = AppUser.supplierPrincipal(
      id: IdGenerator.next(),
      displayName: displayName,
      usernameOrPhone: usernameOrPhone,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
      staffRole: staffRole,
    );
    final created = _datasource.createAccount(user, usernameOrPhone, password);
    await _persistSessionKey(usernameOrPhone);
    return created;
  }

  @override
  Future<void> logout() async {
    _datasource.logout();
    await _prefs.remove(_sessionKeyPref);
  }

  @override
  Future<void> restoreSession() async {
    final key = _prefs.getString(_sessionKeyPref);
    if (key == null) return;
    final user = _datasource.findByKey(key);
    if (user != null) {
      _datasource.restoreCurrentUser(user);
    }
  }

  @override
  Future<void> updateSupplierVerificationStatus({
    required String userId,
    required VerificationStatus status,
  }) async {
    _datasource.updateSupplierVerificationStatus(userId, status);
  }

  Future<void> _persistSessionKey(String usernameOrPhone) async {
    await _prefs.setString(_sessionKeyPref, usernameOrPhone);
  }
}
