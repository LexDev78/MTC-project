enum UserRole { client, supplierTiers, supplierPrincipal, livreur }

/// Où en est le dossier d'un livreur. Il s'inscrit librement mais reste
/// [pending] : aucune course ne lui est proposée tant qu'un agent MTC ne l'a
/// pas approuvé — il manipule la marchandise, parfois l'argent.
enum CourierStatus {
  pending,
  approved,
  rejected,
  suspended;

  String get label => switch (this) {
    CourierStatus.pending => 'En attente de validation',
    CourierStatus.approved => 'Validé',
    CourierStatus.rejected => 'Refusé',
    CourierStatus.suspended => 'Suspendu',
  };
}

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
