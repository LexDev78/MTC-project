import '../entities/supplier_collaborator.dart';
import '../entities/supplier_dashboard_stats.dart';
import 'package:mtc_app/features/auth/domain/entities/user_role.dart'
    show SupplierLegalType, VerificationStatus;
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

import '../entities/supplier_profile.dart';

abstract interface class SupplierRepository {
  Stream<List<SupplierProfile>> watchByType(SupplierType type);

  Future<SupplierProfile> getById(String id);

  Stream<List<SupplierProfile>> watchTopRated({int limit = 5});

  /// Les boutiques que le client peut visiter (« Boutiques du Mali ») :
  /// identité vérifiée, ou MTC Officiel.
  Future<List<SupplierProfile>> fetchListed();

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

  /// Replaces every editable storefront field at once (like
  /// `ProductRepository.updateProduct`) — the caller submits the whole
  /// current set rather than a partial patch, so there's no ambiguity
  /// between "field left unchanged" and "field cleared".
  /// Ce que la boutique montre d'elle-même : son nom, sa bannière, sa
  /// description, ses horaires, ses téléphones.
  ///
  /// Séparé de [updateLocation], et pas par goût du découpage : les deux
  /// écrans qui enregistrent n'éditent pas les mêmes champs. Une seule
  /// méthode écrivant tout obligerait chacun à renvoyer les valeurs de
  /// l'autre, et celui qui aurait des données périmées en mémoire les
  /// réécrirait par-dessus les modifications fraîches.
  Future<void> updateStorefront({
    required String supplierId,
    required String businessName,
    required String? description,
    required String? bannerUrl,
    required List<String> publicPhoneNumbers,
    required String? openingHoursLabel,
  });

  /// Où la boutique se trouve, et où elle livre.
  Future<void> updateLocation({
    required String supplierId,
    required String? fullAddress,
    required double? addressLatitude,
    required double? addressLongitude,
    required List<String> deliveryZones,
  });

  /// Les chiffres du tableau de bord du fournisseur connecté : ventes,
  /// vues, chiffre d'affaires livré, versements. Pas la commission ni le
  /// net — ceux-là suivent une règle qui vit dans
  /// `compute_financial_summary.dart`.
  Future<SupplierDashboardStats> fetchDashboardStats();

  /// L'équipe de la boutique. Vide pour un collaborateur : il n'a pas à
  /// connaître les accès de ses collègues.
  Future<List<SupplierCollaborator>> fetchCollaborators();

  /// Crée le compte d'un collaborateur et le rattache à la boutique.
  ///
  /// Rend son identifiant **et** le mot de passe à usage unique engendré
  /// par le serveur. Le patron ne le choisit pas : il le dicte, et le
  /// collaborateur doit le remplacer à sa première connexion (`0098`).
  Future<({String userId, String temporaryPassword})> createCollaborator({
    required String displayName,
    required String usernameOrPhone,
    required String phoneNumber,
    required Set<String> permissions,
  });

  Future<void> setCollaboratorPermissions({
    required String userId,
    required Set<String> permissions,
  });

  /// Retire l'accès. Le compte continue d'exister : il porte peut-être des
  /// commandes traitées et des messages envoyés, dont l'auteur doit rester
  /// lisible.
  Future<void> removeCollaborator(String userId);

  /// Rétablit l'accès d'un collaborateur retiré.
  Future<void> reactivateCollaborator(String userId);

  Future<void> setOpen({required String supplierId, required bool isOpen});
}
