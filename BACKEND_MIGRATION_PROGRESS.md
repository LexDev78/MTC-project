# Migration backend Supabase — suivi d'avancement

Ce fichier est le point de reprise pour la migration du backend simulé
(in-memory) vers un vrai backend Supabase (Postgres + Auth/sessions + Row
Level Security). Le plan d'origine, complet et détaillé (schéma, RLS,
storage, stratégie de tests, séquence des 12 lots), est dans
`/Users/solomon/.claude/plans/purrfect-swimming-fog.md` — **le lire en
premier** si le contexte ci-dessous ne suffit pas.

**État au 2026-08-13** : **Lots 0, 1, 2, 3, 4 et 5 terminés.** Panier,
favoris et commandes sont désormais **réels** (Postgres + RLS +
`placeOrder`/`updateGroupStatus` en RPC atomiques), en plus de
l'auth/fournisseurs/catalogue (Lots 3-4). Chat/commentaires/avis/
finances/KYC restent in-memory jusqu'à leurs lots respectifs. Reprendre
au Lot 6 (Onboarding fournisseur + Finances).

## Stack locale — infos de connexion

Démarrée via `supabase start` (Docker doit être lancé au préalable,
`docker info` doit répondre). Arrêt : `supabase stop`. Reset complet
(rejoue migrations+seed) : `supabase db reset`.

- API : `http://127.0.0.1:54321`
- Studio (UI web d'admin/inspection des tables) : `http://127.0.0.1:54323`
- DB directe (psql/migrations) : `postgresql://postgres:postgres@127.0.0.1:54322/postgres`
- Clé publique (anon/publishable, safe côté client) : `sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`
- Clé secrète (service_role, **jamais dans l'app Flutter**, uniquement
  scripts de seed/tests locaux) : `sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz`

Ces valeurs sont ré-affichables à tout moment via `supabase status`
(depuis `/Users/solomon/MTC project`) — pas besoin de les retenir par
cœur. Ce sont les clés de démo bien connues du CLI Supabase pour tout
projet local (dérivées du même `JWT_SECRET` fixe
`super-secret-jwt-token-with-at-least-32-characters-long`), donc sans
risque de les avoir en clair ici.

Pour lancer l'app contre cette stack :
```
flutter run --dart-define=SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH
```
(l'URL par défaut `http://127.0.0.1:54321` est déjà câblée dans
`lib/bootstrap.dart`, seule la clé doit être fournie).

**Note disque** : le premier `supabase start` a échoué à cause d'un
disque quasi plein (Docker Desktop avait un disque virtuel `Docker.raw`
de 228 Go apparents = quasi tout le disque). Résolu en supprimant ce
fichier (vide, sans donnée réelle stockée) + en libérant ~26 Go côté
simulateurs iOS/cache Xcode (sans rapport avec Supabase — pré-existant
sur cette machine). Si un futur `docker`/`supabase` échoue à nouveau avec
une erreur d'I/O, vérifier `df -h /` en premier avant de creuser autre
chose.

## Comment reprendre

1. Lire ce fichier en entier, et le plan d'origine si besoin de détail
   (schéma SQL exact, policies RLS, buckets Storage).
2. Vérifier que le blocage ci-dessus est levé (`docker info` répond,
   `supabase --version` fonctionne).
3. `flutter analyze`, `flutter test --exclude-tags integration`, et
   `flutter test --tags integration --concurrency=1` (**`--concurrency=1`
   obligatoire** — sinon plusieurs fichiers tronquent la même base en
   parallèle et provoquent de vrais deadlocks Postgres, voir Lot 3)
   doivent être propres avant de commencer un nouveau lot.
4. Continuer lot par lot, dans l'ordre du plan. Après chaque lot :
   `dart run build_runner build --delete-conflicting-outputs`, puis les
   trois commandes de vérification ci-dessus.

## Principe non négociable (rappel du plan d'origine)

Chaque feature garde sa séparation `domain/entities` →
`domain/repositories` (interface abstraite, **jamais modifiée** par
cette migration) → `data/datasources`+`data/repositories` (**seule chose
remplacée**, `InMemoryXxx` → `SupabaseXxx`) → `presentation/providers`
(seul le *corps* de `xxxRepositoryProvider` change, jamais son nom/type).
Les controllers d'orchestration cross-repository ne changent pas. Si un
lot semble nécessiter de toucher une interface de repository ou un
controller existant, s'arrêter et vérifier qu'on n'a pas mal compris le
contrat avant de continuer.

## Décisions d'architecture actées (détail complet dans le plan)

- Login par `usernameOrPhone` → email synthétique
  `"<usernameOrPhone>@mtc.local"` côté Dart, jamais montré à l'utilisateur.
- `profiles.id` (uuid, = `auth.users.id`) ; pour un fournisseur tiers,
  `suppliers.id == profiles.id` (invariant déjà utilisé par
  `operatingSupplierIdProvider`) ; seul le storefront MTC partagé a un
  `suppliers.id` découplé. Toutes les autres entités métier restent en
  `text` (généré par `IdGenerator.next()` côté Dart, inchangé).
  `DemoIds.dart` garde ses noms de constantes, seules les valeurs passent
  de slugs à des UUID fixes.
- Fonction SQL `operating_supplier_id()` miroir exact de
  `operatingSupplierIdProvider` (Dart), utilisée dans les policies RLS de
  toutes les tables scoped-fournisseur.
- `json_serializable` ajouté en complément de `freezed` sur chaque entité
  pour le mapping Postgres ↔ Dart.
- Tests : nouveau `test/support/supabase_test_harness.dart`
  (`resetAndSeed()`), tests `ProviderContainer`/`MtcApp` taggés
  `integration`, nécessitent `supabase start` actif.
- `tracking/` (simulation live) reste hors schéma, jamais persisté.

## DemoIds — correspondance slug → uuid fixe (UUID v5, `NAMESPACE_DNS`)

Ces valeurs sont déjà utilisées dans `supabase/seed.sql` /
`0002_test_reset_fn.sql` (littéraux `auth.users.id`/`suppliers.id`). **Le
Lot 3 devra mettre à jour `lib/core/mock_data/demo_ids.dart` avec ces
mêmes valeurs exactes** (noms de constantes inchangés, seules les valeurs
passent de slug à uuid) pour que l'app parle des mêmes comptes que le seed.

| Constante | Ancien slug | UUID fixe |
|---|---|---|
| `supplierBogolanBamako` | `supplier-bogolan-bamako` | `b7eb8585-4091-5b6f-83f7-5d70724e97a3` |
| `supplierArtisanatSikasso` | `supplier-artisanat-sikasso` | `b6b1daf0-1c8e-583f-939f-687991d429ca` |
| `supplierElectroBamako` | `supplier-electro-bamako` | `dbff9b88-4829-5eed-b15a-78c33431553f` |
| `supplierAlimentationSegou` | `supplier-alimentation-segou` | `2c66294c-e1d7-59f1-925c-5ab6703827f3` |
| `supplierMateriauxKoutiala` | `supplier-materiaux-koutiala` | `01e2be08-764b-5ea6-8a32-a1b5152497b1` |
| `supplierTissusMopti` | `supplier-tissus-mopti` | `b8e6fcc1-ef1c-5248-8ffa-5de27e9beebb` |
| `supplierCoutureKayes` | `supplier-couture-kayes` | `bc82e68c-b1d9-538a-a8ed-8393a5ba739f` |
| `supplierFruitsNiono` | `supplier-fruits-niono` | `deb94bf5-bddb-5399-8010-3b0264c98f1a` |
| `supplierMtcOfficiel` | `supplier-mtc-officiel` | `3331cbb4-0a65-5f94-9812-fe4270e50fe2` |
| `clientAwa` | `client-awa-traore` | `04060d99-e34d-520e-8b75-631ff4d3c10c` |
| `clientMoussa` | `client-moussa-diarra` | `3355adef-385d-5eee-a565-815c8cf8e4d3` |
| `staffAgent` | `staff-agent` | `0354c601-5e09-57b6-a23c-affaa5acf0d0` |
| `staffAdmin` | `staff-admin` | `2358888a-b13d-56f8-858b-a0c63831b512` |

Comptes de connexion (email synthétique `<usernameOrPhone>@mtc.local`,
mot de passe `password123` pour tous) : `client1`/`client2`,
`fournisseur1`..`fournisseur4` (les 4 tiers avec vérification
verified/pending/unverified/rejected, dossier KYC dans la narration),
`agent1`, `admin1`. **Depuis le Lot 5** : `fournisseur5`..`fournisseur8`
ajoutés pour `ElectroBamako`/`AlimentationSegou`/`MateriauxKoutiala`/
`TissusMopti` — ces 4 fournisseurs "de remplissage catalogue" n'avaient
d'abord aucun compte (comme dans le mock in-memory d'origine), mais
plusieurs tests Lot 5 ont besoin d'une vraie session pour eux (vue
commande côté fournisseur, `update_order_group_status`...) ; `suppliers`
pour ces 4 est désormais créé par `handle_new_user()` (même trigger que
fournisseur1-4), pas par un `insert` direct — mêmes UUID fixes
qu'avant, donc aucune référence existante cassée.

## Fait (Lot 0 — terminé)

- Supabase CLI installé via Homebrew (`brew install supabase/tap/supabase`,
  v2.114.0).
- `supabase init` exécuté — `supabase/config.toml` généré (port API local
  `54321`, confirmé dans le fichier).
- `supabase_flutter: ^2.17.1` ajouté à `pubspec.yaml` (`flutter pub add`).
- `lib/core/di/providers.dart` : nouveau `supabaseClientProvider`
  (`Provider<SupabaseClient>`, même pattern que `sharedPreferencesProvider`
  — lève `UnimplementedError` si non overridé).
- `lib/bootstrap.dart` : `Supabase.initialize(url: ..., publishableKey:
  ...)` avant `runApp` (paramètre `publishableKey` plutôt que `anonKey`,
  déprécié dans `supabase_flutter` 2.17). URL par défaut
  `http://127.0.0.1:54321` (compile-time `String.fromEnvironment`, pas de
  secret) ; clé requise via `--dart-define=SUPABASE_ANON_KEY=...` (pas de
  valeur devinée/codée en dur — la clé locale n'est pas fixe entre
  versions du CLI et je préfère ne pas risquer une valeur fausse
  silencieuse plutôt que de la garantir). `assert` explicite si absente.
- `flutter analyze` propre, **153/153 tests toujours verts** (l'app tourne
  encore entièrement sur les repositories in-memory — aucun changement de
  comportement à ce stade, uniquement du câblage d'infra).
- Docker Desktop installé (`brew install --cask docker`, action manuelle
  utilisateur — mot de passe sudo requis, non automatisable par un agent).
- **Incident disque résolu** (voir "Note disque" ci-dessus) : premier
  `supabase start` a échoué avec une erreur I/O car le disque hôte n'avait
  quasi plus d'espace libre. Diagnostiqué et corrigé (Docker.raw supprimé,
  ~26 Go libérés côté simulateurs iOS/Xcode).
- `supabase start` réussi — stack locale (Postgres, Auth/GoTrue, PostgREST,
  Realtime, Storage, Studio...) up. Vérifié via `curl` sur l'API REST
  (200) et Studio (307, normal). Infos de connexion documentées ci-dessus.

## Fait (Lot 1 — terminé)

- `supabase/migrations/0001_initial_schema.sql` : 21 enums, 21 tables
  (toutes sauf `tracking` et `stock_movements`/`pickup_points` restent
  vides côté seed — schéma présent), `operating_supplier_id()` +
  `is_staff()`/`is_admin()` (helpers RLS), trigger `handle_new_user()` sur
  `auth.users`, RLS complète (4 patterns du plan) sur chaque table,
  section GRANT explicite, 6 buckets Storage + policies par convention de
  dossier (`supplier_id`/`conversation_id`/`order_id`/`auth.uid()` selon
  le bucket).
- `supabase/migrations/0002_test_reset_fn.sql` : `test_reset_and_seed()`
  — source unique de vérité du seed (voir note DRY ci-dessous),
  `security definer`, exécution restreinte à `service_role`.
- `supabase/seed.sql` : réduit à un simple appel à
  `test_reset_and_seed()`.
- Appliqué et vérifié via `supabase db reset` + requêtes directes
  (`docker exec ... psql`) et **vraies requêtes HTTP** contre l'API
  locale : login réel (`/auth/v1/token?grant_type=password`) pour
  `client1`, `fournisseur1`, `admin1` ; lecture publique du catalogue par
  `anon` ; RLS confirmée par rôle (un client ne voit que ses propres
  adresses/panier/favoris ; un fournisseur ne peut modifier que ses
  propres produits, pas ceux d'un autre ; `order_supplier_groups` respecte
  la frontière de confidentialité par fournisseur ; `admin1` voit tout via
  `is_admin()`) ; hydratation imbriquée PostgREST
  (`orders(*, supplierGroups:order_supplier_groups(*, items:order_items(*)))`)
  vérifiée fonctionnelle.
- `flutter analyze` propre, **153/153 tests toujours verts** (aucun
  fichier Dart modifié dans ce lot).

### Pièges rencontrés (utile si un futur lot touche à nouveau ces fichiers)
- **`search_path` d'une fonction `security definer` masque le
  `search_path` de session** : `set search_path = public` sur
  `test_reset_and_seed()` empêchait de résoudre `crypt()`/`gen_salt()`
  (pgcrypto vit dans le schéma `extensions` sur Supabase local, pas
  `public`). Corrigé en `set search_path = public, extensions`.
- **`auth.users` a plusieurs colonnes texte sans défaut** (`email_change`,
  `email_change_token_new`...) : NULL au lieu de `''` fait planter GoTrue
  au login (`sql: Scan error ... converting NULL to string`), pas à
  l'insertion — l'erreur n'apparaît qu'au premier vrai `signInWithPassword`.
  Toujours les insérer explicitement à `''`.
- **Une base Supabase locale fraîche n'accorde PAS automatiquement de
  privilèges table à `anon`/`authenticated`** sur de nouvelles tables
  `public.*` — sans `GRANT`, PostgREST répond "permission denied" avant
  même d'évaluer la RLS. Section GRANT explicite ajoutée (section 6 de
  `0001_initial_schema.sql`).
- **Récursion RLS entre `orders` et `order_supplier_groups`** : chaque
  table consultait l'autre dans sa propre policy → "infinite recursion
  detected in policy". Même classe de problème que celui déjà anticipé
  pour `operating_supplier_id()`/`profiles` dans le plan d'origine, mais
  pas repéré à l'écriture initiale — seulement au test HTTP réel. Corrigé
  avec deux fonctions `security definer` (`order_client_id()`,
  `order_has_group_for_supplier()`) qui lisent l'autre table hors RLS,
  cassant le cycle. **Leçon pour les lots suivants** : toute paire de
  tables dont les policies se référencent mutuellement doit passer par un
  helper `security definer`, jamais une sous-requête directe des deux
  côtés — et ça ne se voit qu'en testant une vraie requête HTTP
  authentifiée, pas en relisant le SQL.
- **`test_reset_and_seed()` contient le seed complet** (pas
  `supabase/seed.sql`) pour éviter la duplication : le harnais de test du
  Lot 3 appellera directement cette fonction via RPC, et `seed.sql`
  (rejoué par `supabase db reset`) se contente de l'appeler aussi. Toute
  future modification du seed doit se faire dans
  `0002_test_reset_fn.sql`, pas dans `seed.sql`.
- **2 commandes ajoutées au-delà du port littéral** :
  `seed-order-1`/`seed-order-2` (+ leurs groupes/items) n'existaient pas
  dans le mock in-memory — les avis `seed-review-1`/`seed-review-2`
  pointaient vers des ids jamais résolus (le mock ne vérifiait aucune
  intégrité référentielle). Postgres l'impose désormais (FK
  `reviews.order_id`/`supplier_group_id`), donc deux commandes minimales
  livrées ont été ajoutées pour rester cohérent. Documenté dans les
  commentaires SQL des deux fichiers concernés.

## Fait (Lot 2 — terminé)

- `pubspec.yaml` : `json_annotation: ^4.9.0` (dépendance directe) +
  `json_serializable: ^6.9.0` (dev). **Versions pinnées volontairement** —
  `flutter pub add json_annotation` seul choisit par défaut la dernière
  version (4.12.0), incompatible avec `freezed ^2.5.7` (conflit de
  résolution sur `source_gen`/`macros`). Ne pas les bumper sans vérifier
  d'abord que `freezed` suit.
- `build.yaml` (racine du projet) : `field_rename: snake` global pour
  `json_serializable` — évite d'annoter chaque classe individuellement,
  chaque champ camelCase (`supplierId`) mappe automatiquement vers son nom
  de colonne snake_case (`supplier_id`) du schéma Lot 1.
- `part 'xxx.g.dart';` + `factory Xxx.fromJson(...)` ajoutés à 18 fichiers
  d'entités (toutes les entités réellement persistées des 14 features :
  suppliers, catalog (Product + StockMovement), cart, favorites, profile
  (Address), orders (Order/OrderSupplierGroup/OrderItem/PickupPoint),
  chat, comments, ratings, supplier_finance (PayoutRequest +
  SupplierFinanceSettings), notifications, supplier_onboarding
  (SupplierDocument uniquement)).
- `@JsonValue('snake_case')` ajouté sur chaque valeur d'enum multi-mot
  dont le nom Dart camelCase diverge de la valeur Postgres choisie au
  Lot 1 (`inTransit`→`in_transit`, `selfDelivery`→`self_delivery`,
  `rccmCertificate`→`rccm_certificate`, etc. — ~15 enums concernés). Les
  enums mono-mot (`draft`, `active`, `paid`...) n'ont rien reçu : leur nom
  Dart égale déjà la valeur DB choisie.
- **Exceptions volontaires (aucun fromJson/toJson)**, conformément au
  plan : `AppUser` (union scellée, hydratée manuellement depuis la
  jointure `profiles`+`suppliers`, Lot 3) ; `SupplierKyc` et
  `DataProcessingConsent` (union scellée / champs aplatis dans
  `supplier_kyc`, hydratés manuellement, Lot 6) ; `CheckoutGroupInput`
  (DTO de checkout, jamais persisté) ; `SupplierFinancialSummary`
  (toujours recalculé, jamais stocké) ; `ChatParticipant` (paramètre de
  méthode, pas un champ de colonne).
- `dart run build_runner build --delete-conflicting-outputs` : 15
  fichiers `.g.dart` générés (un par fichier source touché — plusieurs
  entités peuvent partager un même fichier, ex. `order.dart` contient
  `OrderItem`+`OrderSupplierGroup`+`Order`).
- `flutter analyze` propre, **153/153 tests toujours verts** — purement
  additif, comme prévu, aucun repository/provider/controller touché.

## Fait (Lot 3 — terminé)

### Code applicatif
- `lib/core/auth/pseudo_email.dart` : `"<usernameOrPhone normalisé>@mtc.local"`.
- `lib/features/auth/data/datasources/supabase_auth_datasource.dart` :
  wrapper fin autour de `SupabaseClient.auth` + lecture brute des lignes
  `profiles`/`suppliers`.
- `lib/features/auth/data/repositories/supabase_auth_repository.dart` :
  implémente `AuthRepository` (interface **inchangée**). Hydrate `AppUser`
  en joignant `profiles`+`suppliers` (réutilise `SupplierProfile.fromJson`
  du Lot 2 plutôt que reparser les enums à la main). Traduit `AuthException`
  → `InvalidCredentialsException`/`UsernameAlreadyTakenException`.
- `lib/features/auth/presentation/providers/auth_providers.dart` : corps de
  `authDatasourceProvider`/`authRepositoryProvider` remplacés ; noms/types
  inchangés. `currentUserProvider`/`justLoggedInProvider` intacts.
- `lib/core/mock_data/demo_ids.dart` : les 13 valeurs sont passées de slugs
  à des UUID v5 fixes (table de correspondance juste au-dessus). Noms de
  constantes inchangés.
- **Bug réel trouvé et corrigé** dans `SupabaseAuthRepository.watchCurrentUser()` :
  un `SupabaseClient` brut (construit hors `Supabase.initialize()`, comme
  le fait le harnais de test) n'émet **jamais** d'événement initial sur
  `onAuthStateChange` s'il n'y a pas de session — seul le wrapper
  `SupabaseAuth` de `supabase_flutter` le fait explicitement au démarrage.
  Sans ça, `currentUserProvider` restait bloqué en `AsyncLoading` pour
  toujours (l'app ne quittait jamais le splash screen). Corrigé en
  amorçant le flux avec `_datasource.currentSession` avant d'écouter
  `onAuthStateChange` — corrige aussi bien l'app réelle que les tests.
- **Bug RLS réel trouvé et corrigé** dans `0001_initial_schema.sql` :
  `suppliers_update_own` ne permettait qu'au fournisseur propriétaire de
  modifier sa ligne — mais `AuthRepository.updateSupplierVerificationStatus`
  (décision KYC du staff) doit modifier la ligne d'un **autre**
  fournisseur. Policy corrigée avec `or is_staff()`.

### Tests — harnais et migration
- `test/support/supabase_test_harness.dart` : `createTestSupabaseClient()`
  (client `anon` frais par test) + `resetAndSeed()` (RPC `service_role`
  `test_reset_and_seed()`, Lot 1). Contient aussi les correctifs
  d'environnement `flutter test` ci-dessous (`_allowRealHttpRequests()`,
  `authFlowType: AuthFlowType.implicit`, `autoRefreshToken: false`).
- 37 fichiers de test migrés : import du harnais, tag
  `@Tags(['integration'])` + `library;` en tête de fichier,
  `supabaseClientProvider.overrideWithValue(createTestSupabaseClient())`
  ajouté partout où `sharedPreferencesProvider` l'était déjà,
  `resetAndSeed()` appelé avant chaque test. Fait par 4 agents en
  parallèle (batches de 9) + moi-même pour les cas particuliers, avec
  vérification `flutter analyze` à chaque étape.
- **Trois pièges d'environnement `flutter_test` découverts et corrigés
  dans le harnais** (aucun n'est spécifique à un fichier de test — corriger
  le harnais une fois suffit) :
  1. `flutter test` installe un faux `HttpOverrides` qui fait échouer
     toute requête HTTP réelle avec un 400 vide, sur **tous** les fichiers
     de test (pas seulement `testWidgets`) — `HttpOverrides.global = null`
     au tout début de `createTestSupabaseClient()`/`resetAndSeed()`.
  2. `GoTrueClient.signUp()` avec le flow PKCE par défaut exige un
     `pkceAsyncStorage` — absent sur un `SupabaseClient` brut (seul
     `Supabase.initialize()` le câble). `authFlowType: AuthFlowType.implicit`
     dans `createTestSupabaseClient()` (app 100% email+mot de passe, pas
     d'OAuth/deep-link, donc PKCE ne sert à rien ici).
  3. `autoRefreshToken: false` — un client de test ne survit jamais assez
     longtemps pour avoir besoin du rafraîchissement automatique, et le
     `Timer` périodique par défaut fait échouer l'invariant
     "no pending timers" de `flutter_test` en fin de test.
- **`flutter test --tags integration` doit tourner avec `--concurrency=1`** :
  par défaut `flutter test` exécute plusieurs fichiers en parallèle : leurs
  `resetAndSeed()` concurrents (`TRUNCATE ... CASCADE` sur les mêmes
  tables) provoquent de vrais deadlocks Postgres (`PostgrestException:
  deadlock detected, code: 40P01`). Avec `--concurrency=1`, aucun deadlock.
- **Deux tests corrigés (pas un bug applicatif — un vrai trou de
  couverture que la RLS révèle)** : `kyc_review_flow_test.dart` appelait
  `KycReviewController.approve()/reject()` sans qu'aucun compte staff ne
  soit connecté sur le client Supabase du test — la RLS bloquait
  correctement l'écriture (un `anon` ne peut pas modifier `suppliers`).
  Corrigé en ajoutant un vrai login (`admin1`/`agent1`) avant l'action,
  exactement comme le fait la vraie console staff avant d'atteindre cet
  écran.
- **Bug de course corrigé dans `supplier_signup_test.dart`** :
  `currentUserProvider.future`, une fois déjà résolu une première fois
  (état signed-out initial dans `setUp`), ne réémet pas forcément avant
  qu'un vrai événement `onAuthStateChange` (async réel, plus l'ancien
  `Stream.multi` synchrone) n'arrive — lu une seconde fois juste après
  l'inscription, il pouvait renvoyer l'ancienne valeur en cache. Corrigé
  avec un court délai réel puis une lecture directe de l'état courant
  (`.valueOrNull`), même motif que `checkout_flow_test.dart` utilisait
  déjà pour `login()`.

### Limitation connue, actée avec l'utilisateur — reportée au Lot 10
- Les tests `ProviderContainer` (63 tests, ~22 fichiers) qui appellent les
  repositories/controllers directement fonctionnent parfaitement contre le
  vrai backend.
- Les ~15 fichiers de test qui construisent `MtcApp` et **tapent** sur le
  formulaire de connexion réel pour atteindre un écran (`login_flow_test.dart`,
  `route_guards_test.dart`, `supplier_shell_test.dart`...) sont
  structurellement migrés (même harnais, `resetAndSeed()` toujours placé
  dans `setUp()` — jamais dans le corps `testWidgets`, sinon blocage
  infini) mais **leurs assertions échouent** : `flutter_test` exécute le
  corps d'un `testWidgets` dans une zone `FakeAsync` qui empêche un appel
  réseau réel déclenché par une interaction UI (`tester.tap()`) de jamais
  aboutir, quelle que soit la stratégie de `pump()`/`pumpAndSettle()`/
  `runAsync()` essayée. C'est une limitation connue de `flutter_test`, pas
  un bug de ce projet — la solution correcte est le package
  `integration_test` (binding sans `FakeAsync`, nécessite un vrai
  device/simulateur). **Décision utilisateur** : reporter au Lot 10, qui
  réserve déjà explicitement ce travail ("stabilisation des timings des
  tests widget, réseau réel même en local"). Ces fichiers échouent
  proprement (assertion ratée après un `pumpAndSettle` borné, jamais un
  blocage) — sûr de les laisser tels quels en attendant.
- `flutter analyze` propre, **62/62 tests non-integration + 63/63 tests
  integration `ProviderContainer` verts** (`--concurrency=1`).

## Fait (Lot 4 — terminé)

### Code applicatif
- `lib/features/suppliers/data/{datasources,repositories}/supabase_supplier_*.dart`,
  `lib/features/catalog/data/{datasources,repositories}/supabase_product_*.dart` :
  implémentent `SupplierRepository`/`ProductRepository` (interfaces
  **inchangées**). Pas de Realtime (hors scope de ce lot, voir plan) —
  chaque datasource notifie un `StreamController` local après ses propres
  écritures, même forme que l'ancien in-memory, adossée à de vraies
  requêtes PostgREST. Filtres de `watchProducts` (catégorie, type,
  recherche texte) poussés côté serveur plutôt que fetch-tout-puis-filtre.
- `lib/features/suppliers/presentation/providers/supplier_providers.dart`,
  `lib/features/catalog/presentation/providers/catalog_providers.dart` :
  corps remplacés, noms/types inchangés. `operating_supplier_providers.dart`
  confirmé intact (aucune dépendance à un datasource).
- **Bug réel trouvé et corrigé** dans `AuthController.signUpSupplierTiers` :
  appelait encore `SupplierRepository.createProfile(...)` après le
  signup — redondant et cassant (conflit de clé primaire) depuis que
  `handle_new_user()` (Lot 1) crée déjà la ligne `suppliers` dans la même
  transaction. Appel supprimé ; `createProfile` reste dans l'interface
  (jamais modifiée) et son implémentation Supabase, juste plus jamais
  invoquée par l'app.
- `lib/core/storage/image_upload.dart` (`uploadPickedImage`) +
  `lib/core/widgets/resolved_image.dart` (`ResolvedImage`) : upload réel
  vers Storage câblé sur les 2 points d'appel prévus par ce lot (photos
  produit dans `supplier_product_form_screen.dart`, bannière fournisseur
  dans `supplier_account_screen.dart`) — chemin objet stocké (jamais une
  URL résolue, conforme au plan), résolu en URL publique à l'affichage.
  6 autres écrans mis à jour pour afficher ce chemin via `ResolvedImage`
  au lieu d'un `Image.asset`/`Image.file` conditionnel dupliqué
  (`product_card.dart`'s `ProductImage` — réutilisé par 5 autres écrans
  via cette seule modification —, `product_detail_screen.dart`,
  `fullscreen_image_viewer.dart`, `supplier_product_list_screen.dart`,
  `supplier_profile_screen.dart`). Vérifié via curl (Storage) : upload
  dans son propre dossier OK, upload dans le dossier d'un autre
  fournisseur refusé (RLS), upload anonyme refusé, lecture publique OK.

### RLS — durcissements et ajouts (`0001_initial_schema.sql`)
- `products_select_public` **resserrée** : ne montre au public que
  `status='active' and is_supplier_verified=true` (avant : `using (true)`,
  le filtrage n'existait que côté Dart dans le mock — n'importe qui
  pouvait lire les brouillons/produits non vérifiés d'un autre fournisseur
  via un appel REST direct). Le propriétaire garde l'accès complet à son
  propre catalogue (`watchMyProducts`).
- Nouvelle fonction `has_reviewed_supplier(supplier_id)` : un client ayant
  laissé un avis peut mettre à jour `suppliers.rating_average`/`rating_count`
  et `products.rating_average`/`rating_count` du fournisseur concerné —
  ni propriétaire ni staff, un cas que `suppliers_update_own` /
  `products_write_own` ne couvraient pas. `suppliers_update_own` élargie
  en conséquence ; nouvelle policy `products_update_rating_reviewer`.
- Nouvelle policy `products_update_verification_staff` : même besoin que
  `suppliers_update_own` (Lot 3) côté `products` —
  `ProductRepository.updateSupplierVerification` (décision KYC du staff)
  modifie les produits d'un fournisseur qui n'est pas l'appelant.

### Régressions temporaires connues et actées avec l'utilisateur (14 tests)
Le checkout (`CheckoutController.placeOrder`) décrémente le stock via
`ProductRepository.adjustStock`, appelé par le **client** qui achète —
pas le fournisseur propriétaire du produit. `products_write_own` (RLS)
ne l'autorise pas, et rien ne peut prouver côté Postgres "ce client a le
droit d'acheter ce produit" tant que panier/commandes restent in-memory
(Lot 5). Même chevauchement pour `has_reviewed_supplier()` tant que les
avis restent in-memory (Lot 7) : la fonction ne voit aucune ligne `reviews`
réelle, donc `ReviewController.submit`'s propagation de note échoue
silencieusement (0 ligne modifiée, RLS filtre sans erreur). **Décision
utilisateur** : ne pas assouplir la RLS maintenant (romprait "surtout la
sécurité" — un client pourrait alors modifier n'importe quel champ d'un
produit actif via un appel REST direct, pas seulement le stock) ni
construire une RPC ad-hoc à refondre. Se résout automatiquement au
Lot 5 (`placeOrder` en RPC `security definer` atomique) et Lot 7 (avis
réels, `has_reviewed_supplier()` voit enfin une vraie ligne). Fichiers
concernés : `checkout_flow_test.dart`, `fulfillment_method_test.dart`(3),
`payment_and_supplier_message_test.dart`(5), `stock_decrement_test.dart`(2),
`supplier_order_flow_test.dart`, `notification_hooks_test.dart`,
`review_flow_test.dart`. Ces échecs sont rapides et propres (assertion
`Expected: true / Actual: false` ou écart numérique), jamais un blocage.

### Tests
- 1 fichier avait un vrai trou de couverture (pas un bug applicatif) :
  `supplier_storefront_update_test.dart` appelait
  `SupplierRepository.updateStorefront` directement, sans connexion
  préalable — RLS bloquait correctement (anon ne peut pas écrire dans
  `suppliers`). Corrigé en ajoutant un login avant l'appel, comme le fait
  déjà la vraie app.
- `flutter analyze` propre, **59/59 tests non-integration verts** (3 tests
  de plus qu'avant sont passés en `integration` — voir ci-dessous),
  **52/94 tests integration verts**, le reste étant exactement les 28
  échecs déjà connus/différés du Lot 3 (tests widget pilotant le vrai
  écran de connexion) + les 14 ci-dessus.
- `product_comments_modal_test.dart` (3 tests) migré vers le harnais
  `integration` : sa dernière assertion ("poster un commentaire") déclenche
  `CommentController.addComment` → `productRepositoryProvider.getById`
  réel depuis un geste UI (`TextInputAction.send`) — même blocage
  `FakeAsync` que les tests de login (Lot 3), rejoint donc la liste des
  28 tests différés au Lot 10 (désormais 29 avec celui-ci, un seul des 3
  tests du fichier étant concerné).
- `test/features/catalog/product_repository_test.dart` et
  `supplier_product_repository_test.dart` testent encore
  `InMemoryProductRepository`/`InMemorySupplierDatasource` directement
  (pas via les providers) — toujours verts (code non supprimé), mais
  testent désormais du code orphelin que l'app n'utilise plus. Volontairement
  non touchés : le plan réserve ce type de portage repository-par-repository
  au Lot 10, et la suppression pure des fichiers in-memory au Lot 11.

## Fait (Lot 5 — terminé)

### Code applicatif
- `lib/features/cart/data/{datasources,repositories}/supabase_cart_*.dart`,
  `lib/features/favorites/data/{datasources,repositories}/supabase_favorite_*.dart` :
  implémentent `CartRepository`/`FavoriteRepository` (interfaces
  **inchangées**), même pattern "notify après ma propre écriture" que le
  Lot 4 (pas de vrai Realtime — cart/favoris sont strictement mono-session).
  Corps de `cart_providers.dart`/`favorite_providers.dart` remplacés, noms
  inchangés.
- `lib/features/orders/data/{datasources,repositories}/supabase_order_*.dart` :
  implémente `OrderRepository`. `placeOrder`/`updateGroupStatus` délèguent
  aux deux RPC Postgres (voir plus bas) — le repository ne fait plus
  aucune écriture directe, seulement construction du payload + traduction
  d'erreur (`PostgrestException` message contenant "Stock insuffisant" →
  `InsufficientStockException`, "Transition invalide" →
  `ValidationException`). `watchOrdersForUser`/`watchOrderById` utilisent
  du **vrai Realtime Postgres** (`.stream(primaryKey:['id'])` sur
  `orders`, filtré) ; `watchOrdersForSupplier`/`watchAllOrders` utilisent
  le même `.stream()` **non filtré**, la RLS de `orders`/
  `order_supplier_groups` faisant tout le travail de scoping (vérifié :
  un fournisseur ne reçoit que les commandes où il a un groupe, un admin
  reçoit tout). `.stream()` ne supportant pas la syntaxe d'embed imbriqué
  de PostgREST, chaque émission déclenche un `.asyncMap()` qui refait un
  `select` imbriqué complet (`*, supplier_groups:order_supplier_groups(*,
  items:order_items(*))`) plutôt que d'exploiter la ligne brute émise.
  `alter publication supabase_realtime add table public.orders;` (seule
  table qui en a besoin — la RPC met toujours à jour la ligne `orders`
  parente, donc écouter là suffit même pour un changement de groupe).
- `supabase/migrations/0003_orders_rpc.sql` (nouveau) : deux fonctions
  `security definer` remplaçant tout accès direct en écriture aux 3
  tables commande (`orders`/`order_supplier_groups`/`order_items` n'ont
  **aucune** policy RLS d'écriture — un `PATCH`/`POST` REST direct est
  désormais impossible, y compris pour le propriétaire) :
  - `place_order(...)` : ne fait jamais confiance à un `client_id` fourni
    par l'appelant (`auth.uid()` uniquement). Valide le stock de **chaque**
    ligne de **chaque** groupe avant toute écriture (erreur
    `'Stock insuffisant pour % : % disponible(s), % demandé(s).'` si une
    seule ligne échoue, aucune commande créée, aucune ligne partiellement
    décrémentée). Insère `orders`+`order_supplier_groups`+`order_items`,
    décrémente `products.stock_quantity` et journalise `stock_movements`
    (raison `'sale'`) pour chaque article — atomique par construction (une
    seule transaction SQL, contrairement à l'ancienne séquence Dart de
    `CheckoutController` qui faisait plusieurs appels non transactionnels).
  - `update_order_group_status(...)` : vérifie que le groupe appartient
    bien à `operating_supplier_id()` de l'appelant (`'Non autorisé à
    modifier ce groupe.'` sinon), puis reproduit exactement la logique de
    validation de transition Dart (`isValidTransition`,
    `order_status_transitions.dart`) côté SQL (`'Transition invalide : %
    → %.'` sinon) avant d'écrire. Recalcule et met à jour le statut global
    de la commande parente avec la même logique de priorité que
    `InMemoryOrderDatasource._deriveOverallStatus`.
- `lib/features/orders/presentation/controllers/checkout_controller.dart` :
  **bug réel trouvé et corrigé** — `placeOrder()` appelait encore
  `productRepository.adjustStock(...)` pour chaque article **après**
  l'appel au repository (reliquat de l'époque in-memory, où `placeOrder`
  ne décrémentait pas le stock lui-même). Le stock est désormais décrémenté
  de façon atomique **à l'intérieur** de `place_order()` — cet appel
  redondant tentait d'écrire dans `products`/`stock_movements` depuis la
  session du **client acheteur**, que la RLS rejette à juste titre (un
  client n'est jamais propriétaire d'un produit). Cassait silencieusement
  **toute** commande réelle (l'appel RPC réussissait, mais le second appel
  faisait échouer `AsyncValue.guard`, donc `placeOrder()` retournait
  `false` même quand la commande avait été créée). Bloc supprimé.

### Seed — 4 nouveaux comptes fournisseur (`0002_test_reset_fn.sql`)
`fournisseur5`..`fournisseur8` (Electro Bamako, Alimentation Ségou,
Matériaux Koutiala, Tissus Mopti) — voir "Comptes de connexion" plus haut
pour le détail et la justification. `suppliers` pour ces 4 est maintenant
créé par le trigger `handle_new_user()` (comme fournisseur1-4) plutôt
qu'un `insert` direct, suivi d'un `update` pour les stats (rating/product
count) — mêmes UUID fixes, donc `products.supplier_id` et tout le reste
du seed restent valides sans changement.

### Nouveau : `supabase/migrations/0004_test_admin_helpers.sql`
Deux RPC **test uniquement** (`security definer`, exécution réservée à
`service_role`, même pattern que `test_reset_and_seed()`) :
`test_adjust_stock(product_id, quantity_delta)` et
`test_fetch_stock_movements(product_id)`. Nécessaires car `service_role`
n'a **aucun grant direct** sur les tables (section 6 de
`0001_initial_schema.sql` ne grant qu'`anon`/`authenticated` — un appel
`_adminClient.from('products')...` échoue avec "permission denied for
table products... GRANT SELECT ON public.products TO service_role").
Utilisées uniquement pour mettre en scène/lire un état qu'aucune session
utilisateur réelle ne pourrait produire/consulter légitimement (stock
d'un produit appartenant à un autre fournisseur ; grand livre
`stock_movements`, privé au fournisseur propriétaire, lu depuis un test
agissant côté client). `test/support/supabase_test_harness.dart` expose
`adjustStockAsAdmin()`/`fetchStockMovementsAsAdmin()` en façade.

### Tests — un vrai bug applicatif + plusieurs trous de couverture RLS
- **Bug réel** (voir plus haut) : `checkout_controller.dart` cassait
  silencieusement toute commande réelle. Trouvé via la suite `integration`
  (`stock_decrement_test.dart` : `Expected: true, Actual: false` malgré une
  RPC qui réussissait) — pas visible via curl seul, qui ne teste que la RPC
  isolément.
- **Trous de couverture RLS** (comportement correct de la vraie sécurité,
  pas un bug — le mock in-memory n'avait aucune notion de "qui est
  connecté" donc ces tests marchaient par accident) :
  - `stock_decrement_test.dart` : ajustait le stock d'un produit
    **Electro Bamako** depuis la session **client2** avant checkout — RLS
    a raison de refuser (un client n'est jamais propriétaire d'un
    produit). Corrigé via `adjustStockAsAdmin()`. Même fichier : lisait
    `stock_movements` (grand livre privé du fournisseur) depuis la session
    client — corrigé via `fetchStockMovementsAsAdmin()`.
  - `cart_flow_test.dart` : les 3 tests manipulaient le panier d'un
    utilisateur sans **jamais** se connecter (`cart_items` est owner-only)
    — corrigé en ajoutant un vrai login par test.
  - `supplier_order_flow_test.dart` : lisait la vue commande d'un
    fournisseur (`supplierOrdersProvider(supplierId)`) en étant connecté
    comme un **tout autre** compte (client, ou personne) — la vue "mon
    groupe" dérive de la session réellement authentifiée
    (`operating_supplier_id()`), pas du paramètre `supplierId` passé à la
    fonction (correct : sinon n'importe qui pourrait usurper la vue d'un
    autre fournisseur juste en changeant un argument Dart). Corrigé en se
    connectant comme le vrai fournisseur propriétaire avant chaque lecture
    — a nécessité les 4 nouveaux comptes fournisseur5-8 ci-dessus.
  - `checkout_flow_test.dart`/`payout_flow_test.dart` : attentes numériques
    obsolètes (nombre de commandes, solde disponible) ne comptaient pas
    `seed-order-1`/`seed-order-2` — ces deux commandes n'existaient dans
    aucun jeu de données in-memory (ajoutées au Lot 1 uniquement pour
    satisfaire la FK `reviews.order_id`, voir "Pièges" du Lot 1) mais
    comptent bien dans tout calcul réel qui parcourt les vraies commandes
    d'un client/fournisseur. Attentes corrigées avec le detail du calcul
    en commentaire.
- **Risque de concurrence découvert pendant la vérification** : lancer
  `flutter test --tags integration` deux fois en arrière-plan sans
  s'assurer que la première instance est bien terminée (ex. un
  arrière-plan lancé via `&&... &` dans un sous-shell qui semble mort mais
  ne l'est pas) fait tourner deux suites en parallèle contre la même DB —
  mêmes deadlocks `TRUNCATE ... CASCADE` que plusieurs fichiers en
  parallèle (Lot 3), plus des échecs en cascade totalement étrangers au
  code touché (jusqu'à un test de login basique). Toujours vérifier
  `ps aux | grep "flutter test"` avant de relancer, et privilégier le
  paramètre `run_in_background` natif de l'outil plutôt qu'un `&` manuel
  en sous-shell.
- `flutter analyze` propre, **59/59 tests non-integration verts**,
  **64/94 tests integration verts** — les 30 échecs restants sont
  exactement les ~29 tests widget différés au Lot 10 (limitation
  `FakeAsync`, Lot 3) + `review_flow_test.dart` (différé au Lot 7, avis
  encore in-memory — voir régression Lot 4 ci-dessus, non résolue par ce
  lot comme prévu). **Les 14 régressions temporaires du Lot 4 liées aux
  commandes/stock sont toutes résolues**, sauf `review_flow_test.dart`
  qui dépendait du Lot 7, pas du Lot 5.

## À faire (Lots 6 → 11, détail complet dans le plan original)

### Lot 6 — Onboarding fournisseur + Finances (PROCHAIN)
- `supplier_onboarding/data/**` (upload KYC), `supplier_finance/data/**`.

### Lot 7 — Commentaires, Avis, Chat, Notifications
- `comments/data/**` (table `comment_likes`), `ratings/data/**`,
  `chat/data/**` (Realtime + pièces jointes), `notifications/data/**`.

### Lot 8 — Profil (adresses)
- `profile/data/**`.

### Lot 9 — Storage transverse
- Les 5 points d'appel `ImagePicker` + les points d'enregistrement vocal
  (`record`) uploadés vers Storage au lieu d'un chemin local.

### Lot 10 — Migration de la suite de tests
- Tag `integration`, harnais reset/seed partout, stabilisation timings.

### Lot 11 — Nettoyage final
- Suppression des 28 fichiers `in_memory_*_datasource.dart`/
  `in_memory_*_repository.dart` ; audit `shared_preferences` restant ;
  clôture de ce fichier.
