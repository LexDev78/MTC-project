import '../entities/supplier_kyc.dart';

/// Contract for a supplier's verification dossier. The in-memory
/// implementation backs this today; a Firebase implementation can replace
/// it later without touching any call site.
abstract interface class SupplierKycRepository {
  /// `null` until the supplier's first draft save.
  Stream<SupplierKyc?> watchForSupplier(String supplierId);

  Future<SupplierKyc> getForSupplier(String supplierId);

  /// The staff review queue — every dossier whose status is in [statuses]
  /// (defaults to `{submitted, underReview}`, i.e. what a reviewer needs to
  /// act on).
  Stream<List<SupplierKyc>> watchQueue({Set<KycReviewStatus>? statuses});

  /// Creates the dossier on first call (empty documents, `draft` status),
  /// or updates the given fields on an existing one. Only the fields
  /// actually passed are changed — the rest keep their current value.
  Future<void> saveDraftCompany({
    required String supplierId,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  });

  /// Creates the dossier on first call (empty documents, `draft` status) if
  /// none exists yet — an individual dossier has no free-text fields of its
  /// own, only documents and consent.
  Future<void> saveDraftIndividual({required String supplierId});

  Future<void> addDocument({
    required String supplierId,
    required SupplierDocumentType type,
    required String filePath,
  });

  Future<void> removeDocument({
    required String supplierId,
    required String documentId,
  });

  Future<void> setConsent({
    required String supplierId,
    required String policyVersion,
  });

  /// Moves the dossier from `draft`/`rejected` to `submitted`. Throws
  /// `ValidationException` if required documents/consent are missing (see
  /// `kyc_requirements.isComplete`).
  Future<void> submit({required String supplierId});

  Future<void> startReview({required String kycId, required String staffId});

  /// Only updates the dossier's own status/review fields — propagating the
  /// decision to `AppUser.verificationStatus`, `SupplierProfile`, and
  /// `Product.isSupplierVerified` is cross-repository orchestration that
  /// belongs in a controller (see `KycReviewController`), not here.
  Future<void> approve({required String kycId, required String staffId});

  Future<void> reject({
    required String kycId,
    required String staffId,
    required String reason,
  });
}
