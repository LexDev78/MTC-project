# Migration backend Supabase — suivi d'avancement

Ce fichier est le point de reprise pour la migration du backend simulé
(in-memory) vers un vrai backend Supabase (Postgres + Auth/sessions + Row
Level Security). Le plan d'origine, complet et détaillé (schéma, RLS,
storage, stratégie de tests, séquence des 12 lots), est dans
`/Users/solomon/.claude/plans/purrfect-swimming-fog.md` — **le lire en
premier** si le contexte ci-dessous ne suffit pas.

**État au 2026-08-14** : **Lots 0 à 10 terminés.** Toutes les 14 features
métier tournent sur le vrai backend Postgres, tous les chemins de
fichiers sont de vrais chemins Storage, et **la suite de tests widget est
désormais migrée vers `integration_test`** — les 16 tests bloqués par
`FakeAsync` depuis le Lot 3 tournent enfin, et ont révélé plusieurs vrais
bugs applicatifs (détail ci-dessous) invisibles jusqu'ici. Reste
uniquement le nettoyage final (Lot 11). Reprendre au Lot 11 (Nettoyage
final).

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

## Fait (Lot 6 — terminé)

### Code applicatif
- `lib/features/supplier_onboarding/data/{datasources,repositories}/supabase_supplier_kyc_*.dart` :
  implémente `SupplierKycRepository` (interface **inchangée**). `SupplierKyc`
  (union scellée company/individual) et `DataProcessingConsent` n'ont
  toujours aucun `fromJson` généré (Lot 2, volontaire) — hydratation
  manuelle dans le repository à partir de la table aplatie
  `supplier_kyc` (discriminée par `legal_type`) + `consent_accepted`/
  `consent_accepted_at`/`consent_policy_version` (3 colonnes aplaties →
  `DataProcessingConsent?`), tandis que `SupplierDocument` (déjà
  `fromJson`/`toJson` généré) est réutilisé tel quel pour le tableau
  `documents` (`select` imbriqué PostgREST, `*, documents:
  supplier_documents(*)`). `submit()`/`setConsent()` gardent leurs gardes
  Dart (`kyc_requirements.isComplete`, "consentement individuel
  uniquement") dans le repository plutôt qu'une RPC — contrairement aux
  commandes (Lot 5), aucune de ces règles n'est un état-machine à
  transitions strictes qu'un `PATCH` REST direct pourrait dangereusement
  contourner (au pire, un dossier mal rempli est rejeté par le staff).
  `saveDraftCompany` reproduit le merge partiel de l'ancien datasource
  in-memory (seuls les champs non-nuls passés écrasent l'existant).
- `lib/features/supplier_finance/data/{datasources,repositories}/supabase_supplier_finance_*.dart` :
  implémente `SupplierFinanceRepository`. `PayoutRequest`/
  `SupplierFinanceSettings` ont déjà leur `fromJson`/`toJson` généré (Lot 2)
  — mapping direct, aucune hydratation manuelle. `getSettings` reproduit
  le comportement in-memory exact : renvoie un défaut
  (`AppConstants.defaultCommissionRatePercent`) **sans** l'insérer tant
  qu'`updateSettings` n'a pas été appelé. `computeFinancialSummary` non
  touché (fonction pure, aucune dépendance repository).
- **Upload réel des documents KYC câblé** (jusqu'ici, `filePath` recevait
  le chemin local brut du device sans jamais être uploadé nulle part) :
  `DocumentUploadTile.onPicked` expose désormais l'`XFile` choisi (plus
  seulement son `.path`) ; `SupplierKycController.addDocument` l'uploade
  via `uploadPickedImage` (bucket `kyc-documents`, dossier
  `<supplierId>`) avant d'enregistrer le chemin objet retourné — même
  découpage "upload avant d'enregistrer" que Lot 4, la logique reste dans
  le controller plutôt que republiée à chaque écran appelant (7+ points
  d'appel dans l'assistant KYC), contrairement à `_pickImage`/`_pickBanner`
  du Lot 4 qui vivent directement dans l'écran (un seul appelant chacun).
  Note : ni l'assistant KYC ni l'écran de revue staff n'affichent jamais
  la miniature d'un document (juste une coche "ajouté") — pas besoin
  d'équivalent `ResolvedImage` pour le bucket privé `kyc-documents`
  (`getPublicUrl` ne fonctionnerait pas dessus ; une URL signée serait
  nécessaire seulement si un jour un aperçu visuel est ajouté).

### RPC — `supabase/migrations/0005_payout_status_rpc.sql`
`updatePayoutStatus` impose une machine à états (`requested →
processing/rejected`, `processing → paid/rejected`, `paid`/`rejected`
terminaux) — jusqu'ici vérifiée uniquement côté Dart
(`InMemorySupplierFinanceDatasource._isValidTransition`). La policy RLS
existante (`payout_requests_update_admin`, `is_admin()` seul) ne validait
aucune transition : même faille que celle fermée pour les commandes au
Lot 5 (un `PATCH` REST direct aurait pu faire régresser un virement déjà
`paid`). Même remède : policy UPDATE **supprimée**, remplacée par
`update_payout_status(payout_id, status, rejection_reason)` — `security
definer`, vérifie `is_admin()` puis la transition avant d'écrire.
`requestPayout` (insertion) n'a pas eu besoin du même traitement : la
policy `payout_requests_insert_own` (`supplier_id =
operating_supplier_id()`) suffit déjà à empêcher un fournisseur de créer
une demande au nom d'un autre, et un montant excessif dans une demande
`requested` n'est qu'une friction pour le staff qui décide ensuite — pas
une fuite de fonds (contrairement au stock, aucune ressource partagée
n'est modifiée avant décision).

### Tests — que des trous de couverture RLS (aucun bug applicatif nouveau)
Même classe de problème qu'aux Lots 5/6 : ces tests appelaient les
repositories directement sans session authentifiée (ou avec le mauvais
compte), ce qui marchait par accident sous l'ancien mock in-memory (aucune
notion de "qui est connecté").
- `kyc_review_flow_test.dart` : les deux tests lisaient le dossier
  (`getForSupplier`) **avant** de se connecter en staff — `supplier_kyc`
  n'a aucun grant `anon` (dossiers KYC privés). Corrigé en avançant le
  login au tout début de chaque test (le commentaire du test anticipait
  déjà le besoin d'authentification pour l'action de décision, juste pas
  pour cette première lecture).
- `supplier_kyc_flow_test.dart` : la lecture de la file de revue staff et
  la lecture/soumission du dossier rejeté de Fruits Niono ne se
  connectaient pas du tout. Corrigé (`admin1` pour la file, `fournisseur4`
  — le vrai propriétaire — pour la resoumission). `addDocument` migré vers
  la nouvelle signature `XFile` avec un fichier réel sur disque (l'upload
  réel exige `file.readAsBytes()`, un chemin `/tmp/xxx.jpg` inexistant ne
  suffit plus).
- `payout_flow_test.dart` : 3 tests ne se connectaient pas du tout
  (`permission denied ... GRANT SELECT ON public.payout_requests TO
  anon`). Corrigés avec le compte pertinent par test — `admin1` pour la
  lecture croisée fournisseur/admin (`is_admin()` laisse passer n'importe
  quelle ligne que le filtre Dart cible déjà, donc le scoping par
  fournisseur reste testé), `fournisseur1` pour créer la demande
  (`payout_requests_insert_own` exige le vrai propriétaire) puis bascule
  vers `admin1` pour les transitions de statut (RPC admin-only), `admin1`
  pour `getSettings`/`updateSettings` (écriture réservée au staff).
  **Bug réel trouvé et corrigé** dans `SupabaseSupplierFinanceRepository.
  updatePayoutStatus` : oubli de traduire la `PostgrestException`
  ("Transition invalide : …") de la RPC en `ValidationException` — le
  test s'attendait à ce type précis (`throwsA(isA<ValidationException>())`),
  recevait la `PostgrestException` brute. Même correctif que Lot 5 pour
  `place_order`/`update_order_group_status`, oublié ici à la première
  passe.
- `notification_hooks_test.dart` : le test `SupplierFinanceController.
  reviewPayout` créait une nouvelle demande de retrait en étant connecté
  `admin1` plutôt que le fournisseur propriétaire — `payout_requests_
  insert_own` refusait ("new row violates row-level security policy").
  Corrigé en basculant vers `fournisseur1` pour la création, puis
  `admin1` pour la revue.
- Un échec transitoire (`PostgrestException: deadlock detected, code:
  40P01`) observé une seule fois sur `stock_decrement_test.dart` (Lot 5,
  non touché par ce lot) a disparu au re-run suivant — bruit
  d'infrastructure Postgres local, pas une régression.
- `flutter analyze` propre, **59/59 tests non-integration verts**,
  **64/94 tests integration verts** — les 30 échecs restants sont
  exactement les ~29 tests widget différés au Lot 10 (limitation
  `FakeAsync`, Lot 3) + `review_flow_test.dart` (différé au Lot 7, avis
  encore in-memory, régression documentée au Lot 4).

## Fait (Lot 7 — terminé)

### Code applicatif
- `lib/features/comments/data/{datasources,repositories}/supabase_product_comment_*.dart` :
  implémente `ProductCommentRepository`. Les lectures passent par la vue
  `product_comments_with_likes` (`0001_initial_schema.sql`, `security_invoker`,
  `array_agg` des `comment_likes`) — sa colonne `liked_by_user_ids` tombe
  exactement sur la clé que `ProductComment.fromJson` (généré, Lot 2)
  attend déjà, donc **aucune hydratation manuelle** n'est nécessaire ici
  (contrairement à `SupplierKyc`, Lot 6). `toggleLike` lit d'abord la ligne
  `comment_likes` existante puis insère/supprime — pas d'upsert atomique,
  mais chaque utilisateur ne peut toggler que sa propre ligne (`comment_
  likes_toggle_own`), donc aucune course inter-utilisateurs possible.
- `lib/features/ratings/data/{datasources,repositories}/supabase_review_*.dart` :
  implémente `ReviewRepository`. `Review` a déjà son `fromJson`/`toJson`
  généré — mapping direct. `reply()` lit d'abord la ligne (lecture publique,
  `reviews_select_public`), vérifie `supplier_id` côté Dart et lève
  `ValidationException` avant même de tenter l'`update`, exactement comme
  l'ancien datasource in-memory — `reviews_update_own_supplier` (RLS)
  offre la même garantie côté serveur en profondeur, mais le message
  d'erreur explicite reste utile côté client. `ReviewController.submit`
  (inchangé) recalcule désormais pour de vrai `suppliers.rating_average`/
  `products.rating_average` via les repositories déjà réels du Lot 4
  (`SupplierRepository.recordReview`, `ProductRepository.
  updateSupplierRating`), autorisé par `has_reviewed_supplier()` (déjà en
  place depuis le Lot 4) — **résout automatiquement la régression
  documentée au Lot 4** (`review_flow_test.dart`), comme prévu.
- `lib/features/chat/data/{datasources,repositories}/supabase_chat_*.dart` :
  implémente `ChatRepository`. Seule feature de ce lot à utiliser du vrai
  Realtime Postgres (`.stream()`) plutôt que "notify after my own write" —
  un fil de discussion doit afficher les messages de l'autre partie en
  direct, sans changer d'écran (`chat_messages`/`chat_conversations`
  ajoutées à la publication `supabase_realtime`,
  `0006_lot7_realtime_and_notifications.sql`). `.stream()` sert uniquement
  de déclencheur ("quelque chose a changé", `.eq()` seul) — chaque
  émission relance un `.select().eq().order()` complet via `.asyncMap()`,
  même pattern que les commandes (Lot 5) et pour la même raison (voir bug
  réel ci-dessous). `sendMessage` fait un insert du message puis relit/
  met à jour la conversation (aperçu, horodatage, compteur non-lu du
  **destinataire** uniquement) en deux appels séquentiels — pas de RPC
  atomique ici : contrairement au stock des commandes, une incohérence
  transitoire entre message et compteur n'a aucun impact sécurité/argent,
  juste un badge momentanément désynchronisé.
- `lib/features/notifications/data/{datasources,repositories}/supabase_notification_*.dart` :
  implémente `NotificationRepository`. Pas de Realtime (le destinataire
  voit la notification à sa prochaine visite d'écran, comme le mock
  in-memory — contrairement au chat, aucun aller-retour synchrone n'est
  attendu côté UI).
- **Upload réel des pièces jointes câblé** (photos + notes vocales,
  jusqu'ici stockées comme chemin local brut, jamais uploadées) :
  `uploadPickedImage` (`lib/core/storage/image_upload.dart`) gagne un
  paramètre `contentType` optionnel — les notes vocales ne sont jamais
  des images (leur `XFile(path)` n'a pas de `mimeType` détecté, contrairement
  à un fichier choisi via `image_picker`), donc le défaut `image/jpeg` de
  la fonction serait faux sans ce paramètre (`'audio/mp4'` passé
  explicitement aux deux points d'appel voix). `DocumentUploadTile`-like :
  `CommentComposer.onSendImage`/`ChatComposer.onSendImage` exposent
  désormais l'`XFile` choisi (pas seulement son `.path`) ; l'upload
  lui-même reste dans les controllers (`CommentController.
  addImageComment/addVoiceComment`, `ChatController.sendImage/
  sendVoiceNote`) plutôt que republié à chaque écran appelant, même choix
  qu'au Lot 6 pour les documents KYC (nombreux points d'appel). Dossier
  Storage : `authorId`/`operatingSupplierId` pour les commentaires
  (`comment-attachments`, public en lecture), `conversationId` pour le
  chat (`chat-attachments`, privé aux deux participants).

### RLS — une vraie lacune comblée (`0006_lot7_realtime_and_notifications.sql`)
`notifications` n'avait **aucune policy INSERT** (trou hérité du Lot 1) —
`NotificationRepository.add()` notifie systématiquement un compte *autre*
que l'appelant (un client qui commande notifie le fournisseur, un staff
qui décide un KYC notifie le fournisseur concerné...), donc aucune règle
de propriété étroite n'est possible ici, contrairement aux commentaires/
messages de chat (toujours scopés à un fil dont l'appelant est déjà
participant). Une notification n'ayant aucune valeur exploitable au-delà
de son propre affichage, `notifications_insert_authenticated for insert
with check (true)` reste un risque mineur (spam de la liste, jamais une
fuite) — même arbitrage que les policies INSERT déjà ouvertes sur les
commentaires.

### Bugs réels trouvés et corrigés
- **`.order(colonne)` sans `ascending:` explicite trie par défaut en
  DESCENDANT, pas ascendant** (piège classique PostgREST/supabase-dart —
  `ascending` vaut `false` par défaut). Repéré dans 4 appels neufs de ce
  lot : `watchForProduct`/`watchForSupplier` (commentaires, devraient être
  chronologiques, plus ancien en premier, comme un fil de discussion),
  `watchMessages` (chat, idem), et rétroactivement `watchQueue` (Lot 6,
  file de revue KYC — devrait être FIFO). Diagnostiqué via un test
  autonome direct contre l'API REST locale (`dart run` d'un script isolé
  imitant exactement la séquence du test qui échouait) après avoir écarté
  à tort une hypothèse de "staleness" du cache de `.stream()`/Realtime —
  la vraie cause était beaucoup plus simple. Corrigé en 4 endroits avec
  `ascending: true` explicite ; tous les autres appels `.order()` du
  projet (Lots 4-6) le précisaient déjà correctement, seuls ceux écrits
  dans ce lot (+ le Lot 6, jamais exercé par un test qui aurait révélé
  l'inversion) avaient l'omission.
- `.stream().eq().order()` chaîné directement sur le stream builder de
  chat s'est révélé peu fiable pour fusionner une ligne fraîchement
  arrivée par Realtime dans l'ordre demandé (symptôme initial identique
  au bug ci-dessus, ce qui a d'abord brouillé le diagnostic). Remplacé
  par le pattern `.stream().eq()` (déclencheur seul) + `.asyncMap()`
  refetch complet, comme les commandes au Lot 5 — plus lent (un aller-retour
  REST par changement plutôt qu'une fusion locale) mais fiable, et déjà le
  choix par défaut établi pour tout ce qui a une forme de requête un peu
  élaborée.

### Tests — que des trous de couverture RLS (même classe qu'aux Lots 5/6)
Tous ces tests appelaient les repositories directement sans session
authentifiée, avec le mauvais compte, ou (nouveau cette fois) avec des
identifiants factices incompatibles avec le vrai schéma :
- `kyc_review_flow_test.dart`-like partout : `notification_hooks_test.dart`
  (5 sur 6 tests), `notification_flow_test.dart` (les deux tests),
  `supplier_chat_flow_test.dart` (les 4 tests), `chat_flow_test.dart` (2
  sur 3), `supplier_review_reply_test.dart` (2 sur 3) — connexion ajoutée
  ou avancée avant la première lecture/écriture qui en avait besoin,
  avec bascule de session (`logout()` puis `login()`) quand un même test
  agit successivement des deux côtés d'une relation (client qui écrit un
  message, puis le fournisseur qui le lit).
- **`notification_flow_test.dart` réécrit plus en profondeur** :
  utilisait des identifiants `'user-a'`/`'user-b'` факtices — `notifications.
  user_id` est une vraie colonne `uuid`, donc ces inserts auraient échoué
  au typage en plus de l'absence de session. Remplacé par de vrais
  comptes seedés (`client1`/`client2`) et le contournement admin ci-dessous
  pour les lectures "d'un autre utilisateur".
- **Nouveau contournement de test** : `fetchNotificationsForUserAsAdmin()`
  (`test/support/supabase_test_harness.dart`, RPC `test_fetch_
  notifications_for_user`, `0007_test_notification_helper.sql`) — un
  déclencheur (checkout, décision KYC/retrait, avis, message) notifie
  presque toujours un compte *différent* de la session qui vient d'agir ;
  se reconnecter comme le destinataire uniquement pour vérifier le
  résultat serait lourd pour un simple contrôle d'existence. Même pattern
  que `fetchStockMovementsAsAdmin` (Lot 5).
- `product_comments_modal_test.dart` : ses 3 tests rejoignent la liste des
  tests widget différés au Lot 10 (limitation `FakeAsync`, Lot 3) — avant
  ce lot, seule sa dernière assertion (poster un commentaire) déclenchait
  un appel réseau réel depuis un geste UI ; désormais la **lecture** du
  fil (`_openModal`, partagée par les 3 tests) en déclenche un aussi,
  donc les 3 y basculent. Pas une régression : conséquence attendue des
  commentaires devenant réels, exactement le raisonnement déjà acté aux
  Lots 3/4 pour la même limitation structurelle de `flutter_test`.
- Un run complet anormalement lent (46 à 64 minutes contre 20-25
  habituellement) a fait apparaître deux échecs ponctuels sans rapport
  avec le code de ce lot — un `PostgrestException: JWT issued at future`
  (dérive d'horloge Docker après une session très longue, résolu par
  `supabase stop && supabase start`) et un timeout de 30s sur un test déjà
  vert par ailleurs, confirmé non reproductible en le relançant seul
  (4 secondes, propre). Bruit d'infrastructure, pas des régressions.
- `flutter analyze` propre, **59/59 tests non-integration verts**,
  **63/94 tests integration verts** — les 31 échecs restants sont
  exactement les tests widget différés au Lot 10 (limitation `FakeAsync`,
  Lot 3), désormais 31 au lieu de 29 (les 3 de `product_comments_modal_
  test.dart` en remplacent 1). **Plus aucun échec « régression connue »** —
  `review_flow_test.dart` (dernière régression du Lot 4) est résolu par
  ce lot comme prévu.

## Fait (Lot 8 — terminé)

Le plus petit lot de la migration — une seule entité (`Address`, 3
méthodes d'interface, déjà `fromJson`/`toJson` généré depuis le Lot 2),
aucune table/RLS/seed nouvelle à écrire (tout existait déjà depuis le Lot
1 : `addresses`, policy unique `addresses_all_own` owner-only, 2 lignes
de seed pour Awa/Moussa).

### Code applicatif
- `lib/features/profile/data/{datasources,repositories}/supabase_address_*.dart` :
  implémente `AddressRepository`. Pur CRUD, aucune logique métier
  (`removeAddress` ignore `userId` comme l'ancien datasource in-memory —
  `addresses_all_own` (RLS) est désormais le seul garde-fou réel, un
  appel avec l'id d'une autre adresse ne supprime simplement rien côté
  serveur).
- `defaultAddressProvider` (`profile_providers.dart`) **volontairement
  inchangé** : continue de prendre `addresses.first` plutôt que de lire
  `profiles.default_address_id` (colonne existante depuis le Lot 1, FK
  vers `addresses.id`, mais jamais renseignée nulle part ni côté seed ni
  côté app — `ClientUser.defaultAddressId` existe côté Dart mais n'est
  lu par aucun provider). Corriger cet écart schéma/app serait un vrai
  changement de comportement, hors périmètre d'un lift-and-shift — noté
  ici pour un lot futur si un jour plusieurs adresses par client doivent
  distinguer une adresse "par défaut" explicite.

### Tests
- **Aucun fichier de test dédié n'existe pour ce feature** (`test/features/profile/`
  n'existe pas) — vérifié uniquement via les 6 fichiers de tests
  `orders`/`notifications` qui dépendent de `addressesProvider`/
  `defaultAddressProvider` pour leur propre setup (`checkout_flow_test.dart`,
  `fulfillment_method_test.dart`, `supplier_order_flow_test.dart`,
  `stock_decrement_test.dart`, `notification_hooks_test.dart`,
  `checkout_dynamic_fee_test.dart`, `payment_and_supplier_message_test.dart`)
  — tous déjà verts avant ce lot, restés verts après.
- `flutter analyze` propre, **59/59 tests non-integration verts**,
  **63/94 tests integration verts** — résultat strictement identique au
  Lot 7 (mêmes 31 échecs, tous déjà connus/différés au Lot 10) : ce lot
  n'a introduit ni corrigé aucune régression, lift-and-shift pur.

## Fait (Lot 9 — terminé)

### État de départ, plus avancé que prévu — et un vrai bug découvert
Les 5 points d'appel `ImagePicker` annoncés par le plan étaient déjà tous
câblés vers Storage (photos produit et bannière au Lot 4, documents KYC au
Lot 6, photos commentaire/chat au Lot 7) — rien à faire côté écriture
image. Mais l'audit de ce lot a révélé que **l'écriture avait couru en
avance sur la lecture** : les bulles de message (chat, commentaires)
affichaient encore les pièces jointes via `Image.file(File(path))`/
`DeviceFileSource(path)`, alors que `path` contient un chemin objet
Storage depuis le Lot 7, plus un chemin local — **toute photo/note vocale
envoyée depuis le Lot 7 était invisible/injouable côté destinataire**,
un vrai régression fonctionnelle passée inaperçue parce que les tests
widget qui l'auraient révélée sont eux-mêmes dans le bucket différé au
Lot 10 (limitation `FakeAsync`).

### Code applicatif
- `lib/core/widgets/resolved_image.dart` : nouveau paramètre `signed`
  (bool, défaut `false`) — bascule entre `getPublicUrl` (buckets publics :
  `product-images`, `supplier-branding`, `comment-attachments`) et un
  `createSignedUrl` frais résolu via `FutureBuilder` (buckets privés :
  `chat-attachments`, `order-messages`, `kyc-documents`). Les appelants
  publics existants (Lot 4) sont inchangés (`signed` par défaut à `false`).
- `lib/core/widgets/voice_note_player.dart` (**nouveau**, déplacé hors de
  `features/orders/` puisqu'utilisé par 4 features) : consolide 4 lecteurs
  audio quasi identiques (checkout, détail commande, bulle de chat, pièce
  jointe commentaire) qui dupliquaient exactement la même logique
  `AudioPlayer`/formatage de durée. `bucket`/`signed` optionnels : `null`
  (défaut) = fichier local (`DeviceFileSource`, pour l'aperçu du
  formulaire checkout avant tout upload) ; sinon résout une URL
  publique/signée **au moment où la lecture démarre**, jamais en avance
  (pas de `createSignedUrl` gaspillé pour un message jamais écouté).
  `color` optionnel pour s'accorder à la couleur de texte d'une bulle de
  chat colorée ("mine" vs "leur" côté).
- `lib/features/chat/presentation/widgets/message_bubble.dart` /
  `lib/features/comments/presentation/widgets/product_comment_tile.dart` :
  `_ImageAttachment` bascule vers `ResolvedImage` (chat : `signed: true`,
  bucket privé ; commentaires : bucket public, pas de signature) ; les
  classes `_VoiceMessage`/`_VoiceAttachment` (dupliquées, ~90 lignes
  chacune) supprimées entièrement au profit de `VoiceNotePlayer` partagé.
- **Message vocal du checkout, dernier point d'écriture réellement
  manquant** — `order-messages` (bucket déjà provisionné au Lot 1, RLS
  `order_messages_visible` keyed par `order_id`) ne peut pas recevoir
  l'upload avant que la commande existe (la policy exige une ligne
  `orders` correspondante), et `place_order()` ne connaît l'id de la
  commande qu'à son propre retour — chicken-and-egg résolu en deux temps,
  même raisonnement que les commandes elles-mêmes (Lot 5) appliqué au
  stockage plutôt qu'au stock : `place_order()` crée la commande sans
  chemin vocal ; `CheckoutController.placeOrder()` uploade ensuite le
  fichier local vers `order-messages/<orderId>/...` (la ligne existe
  désormais, l'upload est autorisé) puis appelle la nouvelle RPC
  `set_order_voice_message()` pour l'attacher. Nouvelle méthode
  d'interface `OrderRepository.attachSupplierVoiceMessage` (seul ajout
  d'interface de ce lot — aucune méthode existante ne pouvait porter ce
  besoin en deux temps ; implémentée aussi côté `InMemoryOrderRepository`,
  orpheline mais doit rester compilable). L'`Order` retourné par
  `placeOrder()` est mis à jour localement (`copyWith`) après l'attache
  pour refléter le chemin final sans un second aller-retour réseau.

### SQL — `supabase/migrations/0008_lot9_order_voice_message.sql`
`set_order_voice_message(order_id, voice_path, duration_seconds)` —
`security definer`, `update ... where id = p_order_id and client_id =
auth.uid()`. Pas de nouveau bucket : `order-messages` existait déjà
depuis le Lot 1 (prévu mais jamais câblé côté app).

### Tests
- `payment_and_supplier_message_test.dart` ("un message vocal…") : le
  test utilisait un chemin factice (`/tmp/voice.m4a`, aucun fichier réel)
  et affirmait que le chemin stocké resterait le chemin local brut — les
  deux hypothèses sont désormais fausses (l'upload lit vraiment le
  fichier, et le chemin stocké est le chemin objet uploadé). Corrigé avec
  un vrai fichier temporaire et une assertion sur le préfixe
  `<orderId>/`.
- `flutter analyze` propre, **59/59 tests non-integration verts**,
  **63/94 tests integration verts** — résultat strictement identique aux
  Lots 7/8 (mêmes 31 échecs, tous déjà connus/différés au Lot 10). Le
  vrai bug de lecture corrigé par ce lot (bulles chat/commentaires
  injouables) n'a **aucun** test qui l'aurait détecté avant Lot 10 (même
  cause : geste UI + réseau réel = `FakeAsync` bloqué) — trouvé par audit
  de code plutôt que par un test rouge, à garder en tête pour le Lot 10 :
  ces écrans mériteront une vérification manuelle une fois `integration_test`
  en place, pas seulement une suite verte.

## Fait (Lot 10 — terminé)

### Le vrai fix : `integration_test` + macOS desktop, pas `FakeAsync`
Les 16 tests widget bloqués depuis le Lot 3 (tout geste UI qui déclenche
un I/O réseau réel ne peut jamais se terminer sous `FakeAsync`) sont migrés
vers le package `integration_test` (ajouté à `pubspec.yaml`), qui fournit
`IntegrationTestWidgetsFlutterBinding` — un binding réel (pas de temps
simulé), exécuté directement contre un build desktop macOS (`flutter test
<fichier> -d macos`) déjà disponible sur cette machine sans avoir à
démarrer de simulateur iOS. Recette mécanique appliquée aux 16 fichiers
(portés depuis `test/` vers un nouveau répertoire `integration_test/` à la
racine, miroir de la structure de `test/`) : retirer `@Tags(['integration'])`
(garder `library;`), ajouter l'import `integration_test/integration_test.dart`,
ajouter `IntegrationTestWidgetsFlutterBinding.ensureInitialized();` en
première ligne de `main()`, corriger le chemin relatif vers
`supabase_test_harness.dart` (un `../` de plus qu'à l'origine, puisque
`integration_test/` est un frère de `test/`, pas un sous-dossier), et
garder le corps de chaque test identique **sauf** les `pump()`/
`pump();pump();` bruts qui suivaient un geste déclenchant un vrai I/O
réseau — sous un binding réel (contrairement à `FakeAsync`), un simple
pump ne garantit pas qu'un `Future` réseau en attente se soit résolu, donc
ceux-là sont devenus des `pumpAndSettle(...)` (ou un `pump(Duration(...))`
brut quand rien ne maintient `hasScheduledFrame` à `true` pendant l'attente
— voir plus bas).

### Découverte clé : un seul fichier par invocation `flutter test -d macos`
Premier réflexe testé (`flutter test integration_test/ -d macos`, tous les
fichiers dans une seule invocation) : seul le **premier** fichier passe —
tous les suivants échouent avec `Failed to foreground app; open returned 1`
puis `Error waiting for a debug connection`. Le binding macOS ne relance
pas proprement l'app entre deux fichiers de test au sein du même process
`flutter test`. Solution : chaque fichier est exécuté comme sa **propre**
invocation `flutter test <fichier> -d macos` (script bash séquentiel,
`run_in_background` jamais `&` manuel — même leçon qu'au Lot 5). Avec ce
découpage, les 16 fichiers passent de façon fiable et reproductible.

### Bugs réels trouvés et corrigés (invisibles avant Lot 10)
- **`lib/features/orders/presentation/providers/supplier_order_providers.dart`** —
  crash réel `Bad state: No element` pour un compte admin/staff consultant
  ses propres ventes MTC directes (`SupplierFinanceScreen`/
  `_PrincipalFinance`). Cause : la policy RLS `orders_select_visible`
  admet **toute** commande à une session admin (`or is_admin()`), pas
  seulement celles où le fournisseur opérant a un groupe — alors que
  `supplierOrdersProvider`/`_toView` supposait (commentaire du Lot 5 à
  l'appui) que la RLS elle-même garantissait déjà ce filtrage, vrai pour
  une session fournisseur normale mais faux pour un admin. `firstWhere`
  plantait sur la première commande tierce sans groupe MTC. Fix :
  filtrage défensif côté Dart (`.where((o) => o.supplierGroups.any(...))`
  avant `_toView`) plutôt que de complexifier la RLS.
- **`lib/features/cart/presentation/providers/cart_providers.dart` +
  4 autres** (`order_providers.dart`, `favorite_providers.dart`,
  `profile_providers.dart`, `chat_providers.dart`) — churn de rebuild
  réel : ces 5 providers font `ref.watch(currentUserProvider).valueOrNull
  ?.id` (toute la valeur), alors que Supabase rejoue les événements
  `onAuthStateChange` à chaque nouvel abonné (`ReplaySubject` sans
  `maxSize` côté `gotrue`) — `SupabaseAuthRepository.watchCurrentUser()`
  ré-hydrate donc un `AppUser` deux fois de suite pour une seule connexion
  (seed `currentSession` + replay de l'événement `signedIn`), et une
  ré-émission (même égale) fait reconstruire ces 5 providers, perdant
  transitoirement leur abonnement local en cours. Corrigé partout avec
  `ref.watch(currentUserProvider.select((u) => u.valueOrNull?.id))` — ne
  reconstruit que si l'id lui-même change. Trouvé par un test
  100 % reproductible (`quick_add_to_cart_test.dart` : le deuxième tap sur
  le bouton panier retombait dans la branche "ajouter" au lieu de
  "retirer").
- Deux tests utilisaient un `currentUserProvider` **factice** (`AppUser
  .client(id: 'test-client', ...)`) sans jamais s'authentifier pour de
  vrai — invisible avec l'ancien backend in-memory (aucune notion de rôle
  Postgres), mais `cart_items`/`comment_likes`/`product_comments` n'ont
  pas de grant `anon` en écriture : `permission denied`. Corrigé en
  signant réellement `client1` via `createTestSupabaseClient()` +
  `signInWithPassword` avant de construire l'arbre de widgets, et en
  laissant `currentUserProvider` s'hydrater normalement plutôt que de le
  surcharger.
- `notification_center_screen_test.dart` : le test insérait une
  notification via le repository **avant** la connexion — la policy
  d'insertion (`notifications_insert_authenticated`) exige un rôle
  authentifié, la session étant encore anonyme à ce moment l'insertion
  échouait silencieusement (permission denied). Corrigé en déplaçant le
  seed après la connexion.
- `supplier_finance_screen_test.dart` : assertion figée sur un solde
  disponible de `12500 FCFA`, valeur héritée de l'ancien seed in-memory —
  le vrai seed Postgres calcule `35000 FCFA` pour ce compte. Corrigé
  l'assertion (pas un bug applicatif, juste une expectation obsolète).

### Un autre `pumpAndSettle` insuffisant, cette fois lié à un `SnackBar`
`_QuickAddToCartButton.onTap` (`product_card.dart`) appelle
`messenger.hideCurrentSnackBar()` avant de ré-afficher un nouveau
`SnackBar` — contrairement au tout premier affichage (rien à masquer),
cette passation masquage→affichage a besoin d'un instant de vrai temps
pour aboutir ; un `pump()` sec la manque parfois. Corrigé avec
`pump(const Duration(milliseconds: 300))` à cet endroit précis dans
`quick_add_to_cart_test.dart`.

### Suppression des 16 originaux et suite finale
Les 16 fichiers d'origine dans `test/` (dupliqués dans
`integration_test/`) sont supprimés. Vérification complète :
- `dart run build_runner build --delete-conflicting-outputs` : propre.
- `flutter analyze` (projet entier) : aucun souci.
- `flutter test --exclude-tags integration` : **59/59 verts**.
- `flutter test --tags integration --concurrency=1` : **63/63 verts** —
  les 31 échecs connus depuis les Lots 7/8/9 (`test/features/...
  Provider container...`) ont disparu, puisque les 16 fichiers qui les
  contenaient n'existent plus dans ce répertoire (déplacés vers
  `integration_test/`).
- `integration_test/` (16 fichiers) exécutés individuellement, chacun via
  sa propre invocation `flutter test <fichier> -d macos` : **16/16
  verts**, de façon reproductible (chaque fichier re-testé plusieurs fois
  après chaque correctif pour écarter la fragilité).

## À faire (Lot 11, détail complet dans le plan original)

### Lot 11 — Nettoyage final (PROCHAIN)
- Suppression des 28 fichiers `in_memory_*_datasource.dart`/
  `in_memory_*_repository.dart` ; audit `shared_preferences` restant ;
  clôture de ce fichier.
