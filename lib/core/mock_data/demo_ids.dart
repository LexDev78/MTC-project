/// Stable IDs shared by every feature's seed data (auth, catalog, suppliers,
/// orders, reviews, chat), so mock records reference each other correctly —
/// e.g. a seeded product's `supplierId` matches the supplier account that
/// can log in and, later, the `SupplierProfile` shown on its public page.
///
/// Values are fixed UUID v5s (deterministic, derived from the original
/// slugs below via `NAMESPACE_DNS`) matching `profiles.id`/`suppliers.id`
/// in `supabase/seed.sql` / `supabase/migrations/0002_test_reset_fn.sql` —
/// see the correspondence table in `BACKEND_MIGRATION_PROGRESS.md` (Lot 1).
/// Only the values changed with the Supabase migration; every call site
/// still references these by constant name, never a raw literal.
abstract final class DemoIds {
  // Tiers suppliers
  static const supplierBogolanBamako = 'b7eb8585-4091-5b6f-83f7-5d70724e97a3'; // supplier-bogolan-bamako
  static const supplierArtisanatSikasso = 'b6b1daf0-1c8e-583f-939f-687991d429ca'; // supplier-artisanat-sikasso
  static const supplierElectroBamako = 'dbff9b88-4829-5eed-b15a-78c33431553f'; // supplier-electro-bamako
  static const supplierAlimentationSegou = '2c66294c-e1d7-59f1-925c-5ab6703827f3'; // supplier-alimentation-segou
  static const supplierMateriauxKoutiala = '01e2be08-764b-5ea6-8a32-a1b5152497b1'; // supplier-materiaux-koutiala
  static const supplierTissusMopti = 'b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb'; // supplier-tissus-mopti

  // Tiers suppliers illustrating the verification state machine's remaining
  // states (the six above are all `verified` or `pending`) — a freshly
  // registered account with no KYC dossier submitted yet, and one whose
  // dossier was reviewed and rejected.
  static const supplierCoutureKayes = 'bc82e68c-b1d9-538a-a8ed-8393a5ba739f'; // supplier-couture-kayes
  static const supplierFruitsNiono = 'deb94bf5-bddb-5399-8010-3b0264c98f1a'; // supplier-fruits-niono

  // MTC principal
  static const supplierMtcOfficiel = '3331cbb4-0a65-5f94-9812-fe4270e50fe2'; // supplier-mtc-officiel

  // Clients
  static const clientAwa = '04060d99-e34d-520e-8b75-631ff4d3c10c'; // client-awa-traore
  static const clientMoussa = '3355adef-385d-5eee-a565-815c8cf8e4d3'; // client-moussa-diarra

  // MTC staff
  static const staffAgent = '0354c601-5e09-57b6-a23c-affaa5acf0d0'; // staff-agent
  static const staffAdmin = '2358888a-b13d-56f8-858b-a0c63831b512'; // staff-admin
}
