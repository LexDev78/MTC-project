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

    /// Facultative, et lue par lui seul (`0121`).
    DateTime? birthDate,

    /// Chemin dans le bucket privé `avatars` : la photo n'est montrée qu'à
    /// son propriétaire. `null` = les initiales.
    String? avatarPath,
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

    /// La boutique que ce compte **opère**, qui n'est pas toujours la
    /// sienne : un collaborateur travaille dans celle de son patron
    /// (`supplier_collaborators`, `0093`). `null` pour un propriétaire —
    /// c'est alors [id], et le dire deux fois inviterait les deux valeurs
    /// à diverger.
    String? operatesSupplierId,

    /// Ce que le patron lui a accordé : `products`, `orders`, `promotions`,
    /// `storefront`, `messages`, `reviews`. Vide pour un propriétaire, qui
    /// a tout sans qu'on ait à le lui donner.
    @Default([]) List<String> permissions,

    /// Vrai tant que le collaborateur n'a pas remplacé le mot de passe à
    /// usage unique que son patron lui a dicté (`0098`). Le routeur
    /// l'immobilise alors sur l'écran de changement : tant que ce code
    /// circule de vive voix, le compte n'est à personne.
    @Default(false) bool mustChangePassword,
  }) = SupplierTiersUser;

  const factory AppUser.courier({
    required String id,
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required DateTime createdAt,
    required CourierStatus courierStatus,
    required String city,
    required bool isOnline,
    String? vehicleLabel,

    /// Date de dépôt des pièces (`0105`). Nulle = rien n'a encore été
    /// envoyé : l'écran d'attente doit alors réclamer le dossier au lieu
    /// d'annoncer un examen qui n'a pas commencé.
    DateTime? documentsSubmittedAt,
  }) = CourierUser;

  const factory AppUser.supplierPrincipal({
    required String id,
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required DateTime createdAt,
    required StaffRole staffRole,

    /// Vrai tant que la session n'a pas été confirmée par le code d'une
    /// application d'authentification (`aal2`), alors que la base l'exige
    /// (`0135`). Le serveur ne reconnaît pas encore ce compte comme staff ;
    /// le routeur l'immobilise sur l'écran du code.
    @Default(false) bool mfaPending,
  }) = SupplierPrincipalUser;
}

extension AppUserRoleX on AppUser {
  UserRole get role => switch (this) {
    ClientUser() => UserRole.client,
    SupplierTiersUser() => UserRole.supplierTiers,
    SupplierPrincipalUser() => UserRole.supplierPrincipal,
    CourierUser() => UserRole.livreur,
  };
}

extension CourierUserX on CourierUser {
  /// Tant que le dossier n'est pas validé, l'app livreur se limite à
  /// l'écran d'attente : aucune course ne lui sera proposée de toute façon
  /// (`offer_delivery_to_next_courier` ne retient que les `approved`).
  bool get canTakeDeliveries => courierStatus == CourierStatus.approved;

  /// La balle est dans son camp : ses pièces ne sont pas déposées, et c'est
  /// ce dépôt qui déclenche l'examen. Vrai aussi après un refus — la
  /// décision remet la date à nul précisément pour qu'il puisse corriger la
  /// pièce en cause et redéposer (`review_courier`, `0105`).
  bool get mustSubmitDocuments =>
      courierStatus != CourierStatus.approved &&
      courierStatus != CourierStatus.suspended &&
      documentsSubmittedAt == null;
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

/// Ce qu'un compte fournisseur peut faire sur la boutique qu'il opère.
///
/// Le propriétaire a tout ; un collaborateur a ce qu'on lui a accordé.
/// Quatre choses ne se délèguent jamais et ne figurent donc pas ici :
/// l'argent, le dossier de vérification, la suppression du compte, et la
/// gestion de l'équipe elle-même.
extension SupplierTiersAccess on SupplierTiersUser {
  bool get isOwner => operatesSupplierId == null;

  /// L'identifiant de la boutique à qui appartiennent produits, commandes
  /// et finances — la sienne, ou celle de son patron.
  String get shopId => operatesSupplierId ?? id;

  bool can(String permission) => isOwner || permissions.contains(permission);
}
