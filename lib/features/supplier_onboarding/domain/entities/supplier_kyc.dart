import 'package:freezed_annotation/freezed_annotation.dart';

part 'supplier_kyc.freezed.dart';

/// Lifecycle of a supplier's verification dossier. A single dossier is
/// mutated in place through these states (no versioned history of past
/// rejections) — consistent with the rest of the app, which doesn't version
/// any other record either.
enum KycReviewStatus {
  /// Nothing submitted yet — the supplier is still filling in the form.
  draft,

  /// Submitted, waiting to be picked up by a reviewer.
  submitted,

  /// A staff member has opened it and is actively reviewing it.
  underReview,
  approved,
  rejected;

  String get label => switch (this) {
    KycReviewStatus.draft => 'Brouillon',
    KycReviewStatus.submitted => 'Soumis',
    KycReviewStatus.underReview => 'En cours de vérification',
    KycReviewStatus.approved => 'Approuvé',
    KycReviewStatus.rejected => 'Rejeté',
  };
}

/// One uploaded document slot. Which [SupplierDocumentType]s apply depends
/// on the dossier's variant (`SupplierKyc.company` vs `.individual`) — see
/// `kyc_requirements.dart`.
enum SupplierDocumentType {
  /// Extrait du Registre du Commerce et du Crédit Mobilier (régime OHADA).
  rccmCertificate,

  /// Alternative to [rccmCertificate] for very small operators: the
  /// simplified OHADA "Entreprenant" status declaration.
  entreprenantDeclaration,

  /// Statuts notariés — optional (an Entreprenant has no legal personality,
  /// so no statutes to notarize).
  articlesOfAssociation,

  /// Numéro d'Identification Fiscale.
  taxId,

  /// The legal representative/manager's national ID (carte NINA).
  managerIdCard,
  proofOfAddress,
  nationalIdFront,
  nationalIdBack,
  selfieWithId;

  String get label => switch (this) {
    SupplierDocumentType.rccmCertificate =>
      'Extrait RCCM (Registre du Commerce)',
    SupplierDocumentType.entreprenantDeclaration =>
      'Déclaration de statut Entreprenant',
    SupplierDocumentType.articlesOfAssociation => 'Statuts de la société',
    SupplierDocumentType.taxId => "Numéro d'Identification Fiscale (NIF)",
    SupplierDocumentType.managerIdCard =>
      "Pièce d'identité du gérant (carte NINA)",
    SupplierDocumentType.proofOfAddress => 'Attestation de domiciliation',
    SupplierDocumentType.nationalIdFront => 'Carte NINA — recto',
    SupplierDocumentType.nationalIdBack => 'Carte NINA — verso',
    SupplierDocumentType.selfieWithId =>
      "Selfie avec votre pièce d'identité",
  };
}

@freezed
class SupplierDocument with _$SupplierDocument {
  const factory SupplierDocument({
    required String id,
    required SupplierDocumentType type,
    required String filePath,
    required DateTime uploadedAt,
  }) = _SupplierDocument;
}

/// Records that the supplier explicitly accepted personal-data processing,
/// per Malian law n°2013-015 / APDP Mali — required before an [individual]
/// dossier can be submitted. [policyVersion] pins which wording of the
/// policy was accepted, so a later policy change is auditable.
@freezed
class DataProcessingConsent with _$DataProcessingConsent {
  const factory DataProcessingConsent({
    required bool accepted,
    required DateTime acceptedAt,
    required String policyVersion,
  }) = _DataProcessingConsent;
}

/// A supplier tiers' verification dossier — sealed on the same axis as
/// `SupplierLegalType`, since a company and an individual seller submit
/// entirely different evidence. Fields shared by both variants (id,
/// supplierId, status, documents, createdAt, submittedAt, reviewedAt,
/// reviewedByStaffId, rejectionReason) are exposed directly on [SupplierKyc]
/// by Freezed; variant-specific fields require pattern matching.
@freezed
sealed class SupplierKyc with _$SupplierKyc {
  const factory SupplierKyc.company({
    required String id,
    required String supplierId,
    required KycReviewStatus status,
    required List<SupplierDocument> documents,
    required DateTime createdAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByStaffId,
    String? rejectionReason,
    String? rccmNumber,
    String? taxId,
    String? legalRepresentativeName,
    String? registeredAddress,
  }) = SupplierKycCompany;

  const factory SupplierKyc.individual({
    required String id,
    required String supplierId,
    required KycReviewStatus status,
    required List<SupplierDocument> documents,
    required DateTime createdAt,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByStaffId,
    String? rejectionReason,
    DataProcessingConsent? consent,
  }) = SupplierKycIndividual;
}
