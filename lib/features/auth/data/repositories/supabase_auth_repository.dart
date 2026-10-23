import 'dart:async';

import 'package:image_picker/image_picker.dart' show XFile;
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

  /// Les relectures demandées par [reloadCurrentUser].
  final _relectures = StreamController<void>.broadcast();

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

    // Les événements de session, et les relectures demandées après une
    // modification du profil faite hors de l'authentification (nom, adresse
    // par défaut) : l'un comme l'autre relit le compte. Sans les relectures,
    // un nouveau nom n'apparaîtrait qu'au prochain rafraîchissement du jeton
    // — et la commande passée entre-temps porterait l'ancien.
    final evenements = StreamController<String?>();
    final abonnements = <StreamSubscription<Object?>>[
      _datasource.onAuthStateChange().listen(
        (state) => evenements.add(state.session?.user.id),
        onError: evenements.addError,
      ),
      _relectures.stream.listen(
        (_) => evenements.add(_datasource.currentSession?.user.id),
      ),
    ];
    try {
      await for (final userId in evenements.stream) {
        yield userId == null ? null : await _hydrateOrSignOutIfDeleted(userId);
      }
    } finally {
      for (final abonnement in abonnements) {
        await abonnement.cancel();
      }
      // Sans `await` : quand on arrive ici par un désabonnement, l'unique
      // écouteur d'`evenements` est déjà annulé, et le `Future` de
      // `close()` n'aboutirait jamais — le désabonnement resterait pendu.
      unawaited(evenements.close());
    }
  }

  @override
  Future<void> reloadCurrentUser() async => _relectures.add(null);

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
    } on CollaboratorAccessRevokedException {
      // Une session ouverte avant le retrait : elle est fermée au prochain
      // événement d'authentification (démarrage, rafraîchissement du jeton),
      // et le routeur renvoie à la connexion — qui, elle, dira pourquoi.
      await _datasource.signOut();
      return null;
    } on AccountNotAttachedException {
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
    try {
      return await _hydrateAppUser(userId);
    } catch (_) {
      // L'authentification a réussi mais le compte ne peut pas être ouvert
      // (accès retiré, compte supprimé, réseau coupé en cours de route) :
      // on referme la session au lieu de la laisser ouverte sans compte
      // derrière. L'erreur remonte telle quelle à l'écran, qui la traduit.
      await _datasource.signOut();
      rethrow;
    }
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

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _datasource.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
    } on AuthException catch (e) {
      throw ValidationException(_messageMotDePasse(e));
    }
  }

  @override
  Future<String?> fetchContactEmail() => _datasource.fetchContactEmail();

  @override
  Future<String> setDisplayName(String displayName) async {
    final String nom;
    try {
      nom = await _datasource.setDisplayName(displayName);
    } on PostgrestException catch (e) {
      // Les refus de `set_my_display_name` sont rédigés pour l'utilisateur.
      throw ValidationException(e.message);
    }
    await reloadCurrentUser();
    return nom;
  }

  @override
  Future<String> setPhoneNumber(String phoneNumber) async {
    final String numero;
    try {
      numero = await _datasource.setPhoneNumber(phoneNumber);
    } on PostgrestException catch (e) {
      // Les refus de `set_my_phone_number` sont rédigés pour l'utilisateur.
      throw ValidationException(e.message);
    }
    await reloadCurrentUser();
    return numero;
  }

  @override
  Future<void> setBirthDate(DateTime? birthDate) async {
    try {
      await _datasource.setBirthDate(birthDate);
    } on PostgrestException catch (e) {
      throw ValidationException(e.message);
    }
    await reloadCurrentUser();
  }

  /// Plafond du bucket `avatars` (`0121`) : refusé ici d'abord, plutôt
  /// qu'après un envoi complet sur un réseau lent.
  static const _photoMaxOctets = 5 * 1024 * 1024;

  @override
  Future<void> setAvatar(XFile? photo, {String? previousPath}) async {
    final userId = _datasource.currentSession?.user.id;
    if (userId == null) {
      throw const ValidationException('Connectez-vous pour changer votre photo.');
    }
    String? chemin;
    if (photo != null) {
      if (await photo.length() > _photoMaxOctets) {
        throw const ValidationException(
          'Cette photo est trop lourde : 5 Mo au plus.',
        );
      }
      chemin = await _datasource.uploadAvatar(userId: userId, photo: photo);
    }
    try {
      await _datasource.setAvatarPath(chemin);
    } on PostgrestException catch (e) {
      // Déposée mais refusée : le fichier ne servirait à rien.
      if (chemin != null) await _effacerSansEchec(chemin);
      throw ValidationException(e.message);
    }
    if (previousPath != null && previousPath != chemin) {
      await _effacerSansEchec(previousPath);
    }
    await reloadCurrentUser();
  }

  /// Un échec ici ne doit pas faire échouer le changement de photo, qui a
  /// déjà eu lieu : la file d'effacement de la base rattrapera le fichier.
  Future<void> _effacerSansEchec(String chemin) async {
    try {
      await _datasource.removeAvatarFile(chemin);
    } catch (_) {}
  }

  @override
  Future<ContactEmailStatus> fetchContactEmailStatus() async {
    final row = await _datasource.fetchContactEmailRow();
    return (
      email: row?['contact_email'] as String?,
      verified: row?['contact_email_verified_at'] != null,
    );
  }

  @override
  Future<ContactEmailCodeRequest> requestContactEmailCode(String email) async {
    final Map<String, dynamic> reponse;
    try {
      reponse = await _datasource.requestContactEmailCode(email);
    } on PostgrestException catch (e) {
      // Les refus de `request_contact_email_code` sont rédigés pour
      // l'utilisateur.
      throw ValidationException(e.message);
    }
    return (
      email: reponse['email'] as String,
      expiresAt: DateTime.parse(reponse['expires_at'] as String),
      resendAfterSeconds: (reponse['resend_after_seconds'] as num).toInt(),
    );
  }

  @override
  Future<String> confirmContactEmail(String code) async {
    final Map<String, dynamic> reponse;
    try {
      reponse = await _datasource.confirmContactEmail(code);
    } on PostgrestException catch (e) {
      throw ValidationException(e.message);
    }
    if (reponse['ok'] != true) {
      throw ValidationException(
        reponse['message'] as String? ?? 'Ce code n\'a pas été accepté.',
      );
    }
    return reponse['email'] as String;
  }

  @override
  Future<PasswordResetRequest> requestPasswordReset(String identifier) async {
    final Map<String, dynamic> reponse;
    try {
      reponse = await _datasource.requestPasswordReset(identifier);
    } on PostgrestException catch (e) {
      // Les refus de `request_password_reset` sont rédigés pour
      // l'utilisateur.
      throw ValidationException(e.message);
    }
    return (
      maskedEmail: reponse['masked_email'] as String,
      expiresAt: DateTime.parse(reponse['expires_at'] as String),
      resendAfterSeconds: (reponse['resend_after_seconds'] as num).toInt(),
    );
  }

  @override
  Future<String> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    final Map<String, dynamic> reponse;
    try {
      reponse = await _datasource.resetPasswordWithCode(
        identifier: identifier,
        code: code,
        newPassword: newPassword,
      );
    } on PostgrestException catch (e) {
      throw ValidationException(e.message);
    }
    if (reponse['ok'] != true) {
      throw ValidationException(
        reponse['message'] as String? ?? 'Ce code n\'a pas été accepté.',
      );
    }
    return reponse['username'] as String;
  }

  @override
  Future<String?> setContactEmail(String? email) async {
    try {
      return await _datasource.setContactEmail(email);
    } on PostgrestException catch (e) {
      // Les refus de `set_my_contact_email` sont déjà rédigés en français
      // pour l'utilisateur ; on les transmet tels quels.
      throw ValidationException(e.message);
    }
  }

  /// Le serveur d'authentification répond en anglais. Ses messages
  /// arrivaient tels quels à l'écran (« New password should be different
  /// from the old password. ») — un client malien n'a pas à lire ça.
  String _messageMotDePasse(AuthException e) {
    final message = e.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Mot de passe actuel incorrect.';
    }
    if (message.contains('should be different')) {
      return 'Le nouveau mot de passe doit être différent de l\'actuel.';
    }
    if (e is AuthWeakPasswordException ||
        message.contains('at least') ||
        message.contains('weak')) {
      return 'Le nouveau mot de passe est trop faible : 6 caractères minimum.';
    }
    return 'Impossible de changer le mot de passe pour le moment. Réessayez.';
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
          birthDate: switch (profileRow['birth_date']) {
            final String date => DateTime.parse(date),
            _ => null,
          },
          avatarPath: profileRow['avatar_path'] as String?,
        );
      case 'supplier_tiers':
        // Deux comptes portent ce rôle : celui qui possède la boutique, et
        // celui que le patron a créé pour l'aider (`0093`). Ce qui les
        // distingue est l'existence d'une ligne `suppliers` à son nom —
        // le collaborateur n'en a pas, et c'est voulu : lui en donner une
        // lui ouvrirait une boutique vide dont personne ne veut.
        final collaboration = await _datasource.fetchCollaborationRow(userId);
        // Un accès retiré (`0110`) : la ligne est là, mais n'ouvre plus rien
        // côté serveur. On le dit, avec le nom de la boutique, plutôt que de
        // reconstituer un compte qui échouerait à chaque écran.
        if (collaboration != null && collaboration['deactivated_at'] != null) {
          throw CollaboratorAccessRevokedException(
            await _datasource.fetchSupplierName(
              collaboration['supplier_id'] as String,
            ),
          );
        }
        final shopId = collaboration?['supplier_id'] as String? ?? userId;
        // `OrNull` : sans boutique à soi ni rattachement, le `.single()`
        // levait `PGRST116`, et c'est ce code que l'écran de connexion
        // affichait au collaborateur retiré.
        final supplierRow = await _datasource.fetchSupplierRowOrNull(shopId);
        if (supplierRow == null) throw const AccountNotAttachedException();
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
