import 'entities/supplier_kyc.dart';

/// Which document slots a dossier must have filled before it can be
/// submitted, besides the registration-proof check handled separately by
/// [isComplete]. Deliberately minimal — it does not encode finer Malian
/// legal nuance (e.g. "statuts required unless registered as Entreprenant"),
/// since that judgment call belongs to the staff reviewer, not hard-coded
/// client-side validation.
List<SupplierDocumentType> requiredDocumentTypes(SupplierKyc kyc) {
  return switch (kyc) {
    SupplierKycCompany() => const [SupplierDocumentType.managerIdCard],
    SupplierKycIndividual() => const [
      SupplierDocumentType.nationalIdFront,
      SupplierDocumentType.nationalIdBack,
      SupplierDocumentType.selfieWithId,
    ],
  };
}

/// A company dossier needs proof of registration — either a full RCCM
/// extract or, for very small operators, the simplified OHADA
/// "Entreprenant" declaration. Either one satisfies this check.
bool _hasRegistrationProof(SupplierKycCompany kyc) {
  final types = kyc.documents.map((d) => d.type).toSet();
  return types.contains(SupplierDocumentType.rccmCertificate) ||
      types.contains(SupplierDocumentType.entreprenantDeclaration);
}

/// Whether [kyc] has everything required to move from `draft`/`rejected` to
/// `submitted` — every type in [requiredDocumentTypes] uploaded, a
/// registration proof for a company dossier, and an accepted
/// [DataProcessingConsent] for an individual one.
bool isComplete(SupplierKyc kyc) {
  final uploadedTypes = kyc.documents.map((d) => d.type).toSet();
  final hasRequiredDocuments = requiredDocumentTypes(
    kyc,
  ).every(uploadedTypes.contains);

  return switch (kyc) {
    SupplierKycCompany() => hasRequiredDocuments && _hasRegistrationProof(kyc),
    SupplierKycIndividual(:final consent) =>
      hasRequiredDocuments && (consent?.accepted ?? false),
  };
}
