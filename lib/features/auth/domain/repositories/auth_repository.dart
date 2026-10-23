import 'package:image_picker/image_picker.dart' show XFile;

import '../entities/app_user.dart';
import '../entities/user_role.dart';

/// Un code de vérification parti : à quelle adresse, jusqu'à quand il vaut,
/// et dans combien de secondes on peut en redemander un.
typedef ContactEmailCodeRequest = ({
  String email,
  DateTime expiresAt,
  int resendAfterSeconds,
});

/// L'adresse e-mail du compte, et si elle a été vérifiée par un code
/// (`0124`). Les adresses enregistrées avant ne l'ont jamais été.
typedef ContactEmailStatus = ({String? email, bool verified});

/// Un code de réinitialisation du mot de passe parti (`0127`) : vers quelle
/// adresse, masquée (« la•••@gmail.com »), jusqu'à quand il vaut, et dans
/// combien de secondes on peut en redemander un.
typedef PasswordResetRequest = ({
  String maskedEmail,
  DateTime expiresAt,
  int resendAfterSeconds,
});

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

  /// Change le mot de passe après avoir vérifié l'actuel. Lève une
  /// `ValidationException` au message lisible par l'utilisateur : ancien
  /// mot de passe faux, nouveau trop court, ou identique à l'ancien.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// L'adresse e-mail de contact (`0109`). Ce n'est **pas** l'identifiant
  /// de connexion, qui reste le téléphone.
  Future<String?> fetchContactEmail();

  /// L'adresse de contact et son état de vérification.
  Future<ContactEmailStatus> fetchContactEmailStatus();

  /// Retire l'adresse de contact. Une nouvelle adresse ne s'enregistre plus
  /// ainsi : elle passe par [requestContactEmailCode] puis
  /// [confirmContactEmail] — le serveur refuse le reste.
  Future<String?> setContactEmail(String? email);

  /// Envoie un code à six chiffres à [email] (`request_contact_email_code`,
  /// `0124`). Le code ne passe pas par l'application. Lève une
  /// `ValidationException` lisible (adresse invalide ou prise, délai avant
  /// un nouvel envoi, trop d'envois).
  Future<ContactEmailCodeRequest> requestContactEmailCode(String email);

  /// Donne le code reçu : l'adresse est alors enregistrée, vérifiée, et
  /// rendue. Un code faux, expiré, ou trop d'essais lèvent une
  /// `ValidationException` qui le dit.
  Future<String> confirmContactEmail(String code);

  /// Mot de passe oublié (`request_password_reset`, `0127`) : envoie un code
  /// à l'adresse e-mail **vérifiée** du compte désigné par [identifier] —
  /// son identifiant de connexion, ou cette adresse elle-même. Appelé sans
  /// être connecté. Lève une `ValidationException` lisible (compte inconnu,
  /// pas d'adresse vérifiée, délai avant un nouvel envoi).
  Future<PasswordResetRequest> requestPasswordReset(String identifier);

  /// Change le mot de passe avec le code reçu, ferme toutes les sessions du
  /// compte, et rend son identifiant de connexion — de quoi s'y connecter
  /// aussitôt, même venu par l'adresse e-mail. Un code faux, expiré, ou un
  /// mot de passe refusé lèvent une `ValidationException` qui le dit.
  Future<String> resetPasswordWithCode({
    required String identifier,
    required String code,
    required String newPassword,
  });

  /// Change le nom affiché du compte (`set_my_display_name`, `0116`) et
  /// relit le compte, pour que le nouveau nom paraisse partout sans
  /// reconnexion. Lève une `ValidationException` au message lisible (trop
  /// court, trop long). Rend le nom tel que le serveur l'a normalisé.
  Future<String> setDisplayName(String displayName);

  /// Change le numéro de téléphone d'un compte client
  /// (`set_my_phone_number`, `0121`), puis relit le compte. Ce n'est pas
  /// l'identifiant de connexion. Les commandes en cours suivent : c'est le
  /// numéro qu'appellera celui qui livre. Rend le numéro sous sa forme
  /// enregistrée (`+223XXXXXXXX`) ; lève une `ValidationException` lisible.
  Future<String> setPhoneNumber(String phoneNumber);

  /// Renseigne la date de naissance, ou la retire (`null`), puis relit le
  /// compte. Seul le client la voit.
  Future<void> setBirthDate(DateTime? birthDate);

  /// Remplace la photo de profil par [photo], ou la retire (`null`), puis
  /// relit le compte. [previousPath], la photo remplacée, est effacée tout
  /// de suite — la base l'a de toute façon mise en file d'effacement.
  Future<void> setAvatar(XFile? photo, {String? previousPath});

  /// Relit le profil du compte en session et le pousse dans
  /// [watchCurrentUser] — après une modification faite hors de
  /// l'authentification (nom, adresse par défaut), sans attendre le
  /// prochain événement de session.
  Future<void> reloadCurrentUser();

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
