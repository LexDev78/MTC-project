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

  // Products (catalog seed, 25)
  static const product001 = 'b0fe527e-1f73-55e6-b24e-4d985576d473'; // product-001
  static const product002 = '62599202-a3f0-5adc-ae1c-fe2a691adf92'; // product-002
  static const product003 = '31987995-52ae-5c1f-81ce-b253f7fe55c3'; // product-003
  static const product004 = '9dde2022-87bd-5f9f-83dc-b0bc162a672c'; // product-004
  static const product005 = '20bb8870-4dcb-5043-be5b-f56eddf74226'; // product-005
  static const product006 = 'c56dbd51-9952-5634-be42-2d05b5423276'; // product-006
  static const product007 = '4c7d3a05-200e-54dd-9b3f-0ba6309a4fa1'; // product-007
  static const product008 = '044fa572-6712-5a24-8878-87a2560c512c'; // product-008
  static const product009 = 'b242533d-856c-51d4-9d45-9ca895dc0bf7'; // product-009
  static const product010 = 'a4804b41-6e94-5c43-b867-aab3a9eaed5a'; // product-010
  static const product011 = 'b3fff077-755b-578a-b5ec-1e00139e3029'; // product-011
  static const product012 = '7a383e7f-0bd1-5d70-9cf7-b17f561f89ef'; // product-012
  static const product013 = '46628e1d-5faf-5e63-b42c-d7d88c15c15f'; // product-013
  static const product014 = '097c45a2-c2b7-5eec-ab84-59733cfcbffd'; // product-014
  static const product015 = 'd9d25e13-71ac-51c4-93f7-ed042a996500'; // product-015
  static const product016 = '09ccc6c1-6606-5da0-9be3-8c043d63f218'; // product-016
  static const product017 = 'eb9c253a-3b34-5d56-b9e6-5cde5e37541d'; // product-017
  static const product018 = '9f5263bf-73c5-5bff-8acf-de477f3e61b8'; // product-018
  static const product019 = 'c3e13535-41ce-52c8-a0e2-89278e9f1526'; // product-019
  static const product020 = 'a860f2ac-e6e1-5ea6-bb29-bee7ea51ab9c'; // product-020
  static const product021 = '3e9e198f-2909-53f2-913b-a819bb0a8702'; // product-021
  static const product022 = '009e96cf-2edd-52fe-a9a4-473cfe6c093a'; // product-022
  static const product023 = '84ac7169-d15e-5562-aa51-e2324cc118ac'; // product-023
  static const product024 = 'd1ad6a10-1e0e-50b6-9537-864a6a1aaafe'; // product-024
  static const product025 = 'c61a70a7-0942-5a17-8ebc-6367bbb34056'; // product-025

  // Orders
  static const orderAwaDelivered = '222a8eb1-59d2-57e4-a57e-7cc382ca72f1'; // order-awa-delivered
  static const orderAwaIntransit = '8b306ef7-cb08-5523-bb49-08b41eabc9ac'; // order-awa-intransit
  static const orderMoussaDelivered = 'f1db68f7-e2b3-5c0e-be0f-ed0098a40807'; // order-moussa-delivered
  static const orderMoussaIntransit = '4d3b32a4-b09d-51ba-8b27-6d839083c131'; // order-moussa-intransit
  static const seedOrder1 = '1e31c8a6-d12e-59e4-ad3b-5af974e9dd19'; // seed-order-1
  static const seedOrder2 = 'ca6f1cdc-ffd4-5bc6-97c3-f33cd52465ee'; // seed-order-2

  // Order supplier groups
  static const groupAwaDelivered1 = 'efbd44fe-a725-533d-ba6c-a9c867b161cb'; // group-awa-delivered-1
  static const groupAwaIntransit1 = 'ca322249-2d39-5557-b97e-2e67eaeb4131'; // group-awa-intransit-1
  static const groupMoussaDelivered1 = '04f30401-2cc9-5e3b-be84-16c5e7ecc81e'; // group-moussa-delivered-1
  static const groupMoussaIntransit1 = '79cc954a-1d1a-5b33-8fc7-07c753975417'; // group-moussa-intransit-1
  static const seedGroup1 = '821d2218-ee1c-50fa-b2b4-9d10895d950d'; // seed-group-1
  static const seedGroup2 = '4f06822c-a3e5-5c68-a4fa-8462c46de343'; // seed-group-2

  // Reviews
  static const seedReview1 = 'c3d4d48f-f9a9-59b5-8798-4a9964995afa'; // seed-review-1
  static const seedReview2 = 'b3a7f841-f4c5-5b1c-aabe-9e76b100b796'; // seed-review-2

  // Supplier KYC dossiers
  static const kycBogolanBamako = '8b080e37-5cd8-54e0-83b2-44ec937749a1'; // kyc-bogolan-bamako
  static const kycArtisanatSikasso = '0c884147-9c42-5893-b253-ab069e5dc9e4'; // kyc-artisanat-sikasso
  static const kycFruitsNiono = 'f3824a79-b8d2-5445-bd5e-53308bc806cd'; // kyc-fruits-niono

  // Supplier KYC documents
  static const docBogolanRccm = '171dcb37-678b-550d-920e-f580ed382da5'; // doc-bogolan-rccm
  static const docBogolanManagerId = 'd698ca07-015a-58d4-9c2b-5a016de69a0a'; // doc-bogolan-manager-id
  static const docSikassoRccm = '19b1dcea-7432-5054-b2bc-c5bedf8d7f8a'; // doc-sikasso-rccm
  static const docSikassoManagerId = 'ca15084c-3e4d-5582-bcbc-c85dd01fc593'; // doc-sikasso-manager-id
  static const docNionoManagerId = 'e7eff388-5320-5ab2-966b-a9530b738b8b'; // doc-niono-manager-id

  // Payout requests
  static const payoutBogolan1 = 'd83fac03-2549-57d2-8725-c122da499036'; // payout-bogolan-1

  // Chat conversations
  static const convAwaBogolan = '41889195-7cbf-5b45-8d95-de49a8b47cd0'; // conv-awa-bogolan
  static const convMoussaMtc = '2fbdae8c-afc9-5053-b47a-6e46ab1a9361'; // conv-moussa-mtc

  // Chat messages
  static const msg1 = '60c32d08-af5f-51e0-b744-2340fb894aab'; // msg-1
  static const msg2 = '6f8c35d7-095a-5944-b617-4bb7d495ed48'; // msg-2
  static const msg3 = '805a78e4-82cb-5369-85e0-f78eade39cc1'; // msg-3

  // Product comments
  static const comment001 = '3d2df89f-c408-5ed7-8d7b-d0b90aeea554'; // comment-001
  static const comment002 = 'b6059714-4354-5cb3-bbbd-da0b7cc32620'; // comment-002
  static const comment003 = '0ba923ec-60a9-59c4-8661-d6f950755c37'; // comment-003
}
