enum UserRole { client, supplierTiers, supplierPrincipal }

enum VerificationStatus { unverified, pending, verified, rejected }

enum StaffRole { agent, admin }

/// How a "fournisseur tiers" registers: [company] identifies itself with
/// business registration documents (RCCM, statuts, NIF...), [individual]
/// (a "fournisseur libre") instead goes through personal identity
/// confirmation (ID photo + selfie) and APDP data-processing consent. Drives
/// which document set `supplier_onboarding` collects.
enum SupplierLegalType {
  company,
  individual;

  String get label => switch (this) {
    SupplierLegalType.company => 'Société / Entreprise',
    SupplierLegalType.individual => 'Vendeur individuel',
  };
}
