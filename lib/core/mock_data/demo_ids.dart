/// Stable IDs shared by every feature's seed data (auth, catalog, suppliers,
/// orders, reviews, chat), so mock records reference each other correctly —
/// e.g. a seeded product's `supplierId` matches the supplier account that
/// can log in and, later, the `SupplierProfile` shown on its public page.
abstract final class DemoIds {
  // Tiers suppliers
  static const supplierBogolanBamako = 'supplier-bogolan-bamako';
  static const supplierArtisanatSikasso = 'supplier-artisanat-sikasso';
  static const supplierElectroBamako = 'supplier-electro-bamako';
  static const supplierAlimentationSegou = 'supplier-alimentation-segou';
  static const supplierMateriauxKoutiala = 'supplier-materiaux-koutiala';
  static const supplierTissusMopti = 'supplier-tissus-mopti';

  // Tiers suppliers illustrating the verification state machine's remaining
  // states (the six above are all `verified` or `pending`) — a freshly
  // registered account with no KYC dossier submitted yet, and one whose
  // dossier was reviewed and rejected.
  static const supplierCoutureKayes = 'supplier-couture-kayes';
  static const supplierFruitsNiono = 'supplier-fruits-niono';

  // MTC principal
  static const supplierMtcOfficiel = 'supplier-mtc-officiel';

  // Clients
  static const clientAwa = 'client-awa-traore';
  static const clientMoussa = 'client-moussa-diarra';

  // MTC staff
  static const staffAgent = 'staff-agent';
  static const staffAdmin = 'staff-admin';
}
