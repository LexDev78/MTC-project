# Espace fournisseur — suivi d'avancement

Ce fichier est le point de reprise pour la construction de l'espace fournisseur
(fournisseur tiers société/individuel + fournisseur principal MTC). Le plan
d'origine, complet et détaillé (contexte, principes d'architecture, séquence
des 13 lots), est dans `/Users/solomon/.claude/plans/structured-inventing-dewdrop.md`
— **le lire en premier** si le contexte ci-dessous ne suffit pas.

**État au 2026-08-13** : **Les 13 lots sont terminés** (analyzer propre, 153
tests verts). Le plan d'espace fournisseur est complet. Ce fichier reste
comme référence/historique — voir "Fait (Lots 1-13)" ci-dessous pour le
détail de chaque lot, et "Hors scope explicite" pour ce qui a été
sciemment laissé de côté. S'il y a une suite (bugs, extensions), repartir
de l'état documenté ici plutôt que de relire tout le plan d'origine.

## Comment reprendre (si des lots restaient — gardé pour référence)

1. Lire ce fichier en entier.
2. `flutter analyze` et `flutter test` doivent être propres avant de commencer
   un nouveau lot (si ce n'est pas le cas, quelque chose a changé entretemps
   — investiguer avant de continuer).
3. Continuer lot par lot, dans l'ordre, en respectant les principes
   d'architecture ci-dessous. Après chaque lot : `dart run build_runner build
   --delete-conflicting-outputs`, puis `flutter analyze` et `flutter test`
   complets (pas seulement les nouveaux fichiers).
4. Écrire des tests dédiés à chaque lot (repository + flow + si UI
   significative, un test widget qui pilote l'écran réel — voir "Leçon
   importante" ci-dessous).

## Principes d'architecture à respecter (non négociables, vérifiés à chaque lot)

1. **Aucune dépendance cross-feature dans `data/`.** Toute orchestration
   entre plusieurs repositories vit dans un `AsyncNotifier` de
   `presentation/controllers/`, jamais dans un repository. Exemple déjà en
   place : `KycReviewController.approve/reject` orchestre `SupplierKycRepository`
   → `AuthRepository` → `SupplierRepository` → `ProductRepository` ; `SupplierProductController.setStatus`
   orchestre `ProductRepository.setStatus` → `SupplierRepository.adjustProductCount`.
2. **Snapshot, pas de jointure live.** `Order.clientDisplayNameSnapshot`/`clientPhoneSnapshot`
   suivent cette convention (comme `OrderItem.productNameSnapshot` déjà présent).
3. **Réutiliser l'existant, ne pas dupliquer.** `image_picker` pour tout
   upload (KYC, photos produit) — aucune nouvelle dépendance nécessaire.
   `ChatRepository.startOrGetConversation` déjà réutilisé tel quel par
   `SupplierOrderController.contactClient`.
4. **Toute entité `@freezed` créée/modifiée** → `dart run build_runner build
   --delete-conflicting-outputs` avant `flutter analyze`/`flutter test`.
5. **`operatingSupplierIdProvider`** (`lib/features/suppliers/presentation/providers/operating_supplier_providers.dart`) :
   pièce centrale qui permet aux mêmes écrans de servir fournisseur tiers ET
   fournisseur principal. Un fournisseur tiers opère sur `supplierId ==
   user.id` ; tout le staff MTC (agent/admin) partage `DemoIds.supplierMtcOfficiel`.
   **Tout nouvel écran/provider de gestion (Lots 8-12) doit lire ce provider**,
   jamais `currentUser.id` directement.
6. **`supplierRoutePrefixProvider`** (même fichier) : retourne `/supplier-tiers`
   ou `/supplier-principal` selon le rôle — utilisé pour construire les routes
   de navigation (`context.push('${ref.read(supplierRoutePrefixProvider)}/...')`)
   depuis un écran partagé entre les deux rôles.
7. **Confidentialité inter-fournisseurs** : toute vue qui expose une commande
   à un fournisseur doit passer par une projection stricte (voir
   `SupplierOrderView` dans `lib/features/orders/presentation/providers/supplier_order_providers.dart`)
   qui ne montre jamais un autre fournisseur du même panier multi-fournisseurs.

## Leçon importante du Lot 5 (à réappliquer)

Un test widget qui pilote réellement un écran (remplissage de formulaire,
taps, navigation — via `flutter_test`/`testWidgets`, pas juste
repository/controller) a trouvé un vrai bug de mise en page (débordement de
20px au clavier dans la feuille d'ajustement de stock, non scrollable) que
les tests de logique pure n'auraient jamais détecté. **`chromium-cli` n'est
pas disponible dans cet environnement** (pas de navigateur pilotable) — le
mécanisme de vérification UI le plus fiable ici est `flutter test` avec de
vrais `testWidgets` qui pilotent l'app complète (voir
`test/features/catalog/supplier_product_screen_test.dart` et
`test/features/orders/supplier_order_screen_test.dart` comme modèles). À
refaire pour chaque lot avec une UI substantielle (Lots 8, 9, 10, 11, 12).

Piège récurrent dans ces tests : après `showModalBottomSheet`, l'écran
derrière reste "onstage" (contrairement à une navigation par route complète)
— donc `find.byType(TextFormField).first` peut cibler un champ de l'écran du
dessous. Utiliser `find.widgetWithText(TextFormField, 'Label')` à la place.
Autre piège : `LoginScreen`/`WelcomeScreen` portent une animation perpétuelle
(le chat qui suit le focus) — ne jamais faire `pumpAndSettle()` en restant
dessus, utiliser des `pump(duration)` fixes.

## Leçon importante du Lot 10 (à réappliquer)

Encore un vrai bug trouvé par un test widget piloté (pas par `flutter
analyze`, qui ne voit rien) : `AppComponentThemes.filledButton`/`.outlinedButton`
fixent globalement `minimumSize: Size.fromHeight(56)` — une largeur
**infinie** (pensé pour les CTA pleine largeur du type "Se connecter"). Un
`FilledButton`/`OutlinedButton` posé nu dans un `Row` (qui donne une largeur
non bornée à ses enfants non-flex pour les mesurer) fait alors planter le
layout (`BoxConstraints forces an infinite width`, sur `RenderPhysicalShape`)
— **mais seulement une fois monté dans l'app réelle avec son thème** ; un
test qui pompe l'écran seul dans un `MaterialApp` nu (thème par défaut) ne le
voit jamais, d'où l'intérêt de piloter l'écran depuis `MtcApp` complet et pas
juste le widget isolé. Corrigé dans `supplier_review_management_screen.dart`
en remplaçant le `Row` de boutons par un `OverflowBar` (ce que
`AlertDialog.actions` utilise déjà en interne, donc déjà implicitement
éprouvé dans ce projet). **Réflexe à appliquer à tout futur `FilledButton`/
`OutlinedButton` qui n'est ni pleine largeur ni dans des `actions` d'`AlertDialog`/
`BottomSheet` standard : passer par `OverflowBar`, ou lui donner un `style`
local qui écrase `minimumSize`.**

## Comptes démo utiles pour les tests

- `client1`/`client2` (Awa Traoré / Moussa Diarra), mdp `password123`.
  Le panier pré-seedé de `client2` couvre **2 fournisseurs différents**
  (Riz Alimentation Ségou + Smartphone Electro Bamako) — utile pour tout
  test de confidentialité inter-fournisseurs.
- `fournisseur1` (Bogolan Bamako, verified, société) — a une commande seedée
  (`order-awa-delivered`, statut `delivered`, donc terminal — pas d'actions
  de transition/annulation possibles dessus).
- `fournisseur2` (Artisanat Sikasso, pending, société) — dossier KYC `submitted`,
  déjà dans la file de review.
- `fournisseur3` (Couture Kayes, unverified, individuel) — aucun dossier KYC,
  aucun produit, aucune commande. Inscription fraîche.
- `fournisseur4` (Fruits Niono, rejected, société) — dossier KYC rejeté avec
  motif, testable en resoumission.
- `agent1`/`admin1` (staff MTC, `StaffRole.agent`/`.admin`) — opèrent sur
  `DemoIds.supplierMtcOfficiel` partagé.
- Mot de passe universel : `password123`.

**Limite connue** : aucun compte démo n'a de commande **non terminale** pour
un fournisseur ayant un login direct (Electro Bamako/Alimentation
Ségou/Matériaux Koutiala ont des commandes `inTransit` mais pas de compte de
connexion dédié). Pour tester une UI de transition de statut de bout en
bout, soit ajouter un compte démo, soit passer par
`SupplierOrderController` directement (voir
`test/features/orders/supplier_order_flow_test.dart` qui utilise
`DemoIds.supplierMateriauxKoutiala` sans connexion, juste via le
repository/controller).

## Fait (Lots 1-13 — plan complet)

- **Lot 1** — `SupplierLegalType{company,individual}`, statut initial
  `unverified` (bug corrigé, était `pending`), création de `SupplierProfile`
  à l'inscription (bug corrigé, n'existait jamais), écran de choix
  société/individuel, 4 comptes démo couvrant les 4 états.
- **Lot 2** — Feature `supplier_onboarding/` complète : `SupplierKyc`
  (union scellée company/individual), documents, consentement APDP,
  assistant de saisie, seed KYC cohérent avec les comptes démo.
- **Lot 3** — Gating routeur (`route_guards.dart`) selon `verificationStatus`,
  file de review KYC côté staff (`kyc_review_queue/detail_screen.dart`),
  `KycReviewController` orchestrant 3 (puis 4 au Lot 5) entités.
- **Lot 4** — `SupplierShell` partagé (6 onglets : Tableau de
  bord/Produits/Commandes/Messages/Finances/Profil), 2 `StatefulShellRoute`
  (un par zone), retrait de `lib/features/supplier_placeholder/`.
- **Lot 5** — CRUD produit complet, `ProductStatus`, `StockMovement`,
  formulaire avec upload photo, feuille d'ajustement de stock rapide.
  **Bug de débordement trouvé et corrigé** (voir "Leçon importante").
- **Lot 6** — Décrément de stock réel à la commande (`CheckoutController`),
  validation en amont (aucun décrément partiel si une ligne échoue).
- **Lot 7** — Gestion des commandes fournisseur : snapshots client,
  `SupplierOrderView` (confidentialité), `isValidTransition`, annulation
  avec motif, bouton "Contacter le client" + routes de fil de discussion
  (préparent le Lot 8).
- **Lot 8** — Messagerie côté fournisseur : `ChatConversation.unreadCount`
  → `unreadCountClient`/`unreadCountSupplier` (compteurs indépendants,
  `sendMessage` incrémente celui du destinataire) ; `enum
  ChatParticipant{client,supplier}` ; `ChatRepository.watchConversationsForSupplier`
  + `markConversationRead({conversationId, readBy})` (ne remet à 0 que le
  compteur du lecteur) ; `ChatController.markRead` dérive `readBy` du rôle
  courant en interne. **Ajout non prévu dans le plan d'origine, nécessaire
  pour que l'écran soit utilisable** : `ChatConversation.clientDisplayNameSnapshot`
  (même convention que `Order.clientDisplayNameSnapshot`) — sans ça,
  `ConversationTile`/`ChatThreadScreen` affichaient toujours
  `supplierName`, donc un fournisseur aurait vu son propre nom sur
  chaque conversation au lieu de celui du client. `ConversationTile`
  et `chat_thread_screen.dart` choisissent maintenant le nom (et, pour
  la tuile, la route) à afficher selon que l'utilisateur courant est
  `ClientUser` ou non. `supplier_conversation_list_screen.dart` rempli.
  Tests : `supplier_chat_flow_test.dart` (repository/controller),
  `supplier_conversation_list_screen_test.dart` (widget, piloté comme
  `supplier_order_screen_test.dart`), `chat_flow_test.dart` adapté au
  renommage.
- **Lot 9** — Boîte de réception des commentaires produits :
  `ProductComment.+ required supplierId` (résolu depuis `product.supplierId`,
  via `ProductRepository.getById` dans `CommentController` — **le ripple
  prévu par le plan d'origine sur 5-6 fichiers UI n'a pas eu lieu** :
  résoudre `supplierId` dans le controller plutôt que de le faire porter
  par chaque widget appelant garde `product_comments_modal.dart`/
  `product_comments_section.dart`/`comment_composer.dart`/
  `product_detail_screen.dart` inchangés). `ProductCommentRepository.+
  watchForSupplier(supplierId)`. Écran `supplier_comment_inbox_screen.dart`
  rempli, accessible via une icône dans l'AppBar de l'onglet "Produits"
  (pas de 7e onglet — décision déjà prise). Projection présentation
  `supplierCommentInboxProvider` (`comments/presentation/providers/
  supplier_comment_inbox_providers.dart`) qui regroupe chaque commentaire
  racine avec ses réponses + le nom du produit (jointure `ProductRepository`
  + `ProductCommentRepository` en présentation, comme `SupplierOrderView`) ;
  taper sur une tuile réutilise `showProductCommentsModal` tel quel plutôt
  que de dupliquer l'UI de réponse. Tests : `supplier_comment_inbox_test.dart`
  (repository/controller/projection), `supplier_comment_inbox_screen_test.dart`
  (widget, piloté comme au Lot 8).
- **Lot 10** — Réponse du fournisseur aux avis : `Review.+
  supplierReply?/supplierRepliedAt?` ; `ReviewRepository.+ reply({reviewId,
  supplierId, reply})` (lève `ValidationException` si `supplierId` ne
  correspond pas à l'avis — testé) ; ré-appeler `reply` édite la réponse en
  place plutôt que d'en ajouter une seconde. `ReviewController.+
  replyToReview` résout le fournisseur via `operatingSupplierIdProvider`.
  `supplier_profile_screen.dart` (vitrine publique) affiche `supplierReply`
  si présent. Écran `supplier_review_management_screen.dart` créé,
  accessible via une icône dans l'AppBar de l'onglet "Profil" (même
  placement que le Lot 9, pas de 7e onglet) — réutilise
  `supplierReviewsProvider` déjà existant, pas de nouveau provider de liste
  nécessaire. **Vrai bug de layout trouvé et corrigé par le test widget**
  (voir "Leçon importante du Lot 10" ci-dessus) : `FilledButton` nu dans un
  `Row` plantait à cause du thème global `minimumSize: Size.fromHeight(56)`
  — remplacé par `OverflowBar`. Tests : `supplier_review_reply_test.dart`
  (repository/controller), `supplier_review_management_screen_test.dart`
  (widget).
- **Lot 11** — Profil vitrine étendu : `SupplierProfile` étendu en place
  (pas de 3e entité) avec `description?, bannerUrl?, fullAddress?,
  addressLatitude?/Longitude?, publicPhoneNumbers ([]), deliveryZones ([]),
  openingHoursLabel?, isOpen (true par défaut)`. `SupplierRepository.+
  updateStorefront(...)` (remplace tout le bloc éditable d'un coup, comme
  `updateProduct`, pas de patch partiel) `+ setOpen(...)`.
  `SupplierAccountController` créé (nouveau — n'existait pas avant) :
  `updateStorefront` **dérive `addressLatitude/Longitude` depuis la ville du
  fournisseur via `MalianCity`** (même table que `ManageAddressesScreen`
  pour une adresse client) plutôt que de les demander dans le formulaire —
  pas de picker de carte dans l'app, donc pas de saisie manuelle de
  coordonnées. `supplier_account_screen.dart` rempli (formulaire + toggle
  "Boutique ouverte" instantané, séparé du reste du formulaire).
  `supplier_profile_screen.dart` (vitrine publique) affiche bannière,
  badge "Ouvert"/"Fermé", description, adresse/horaires/téléphones/zones de
  livraison — **non explicitement demandé par le plan d'origine mais
  nécessaire** : sans ça, le formulaire n'aurait servi à rien (rien ne
  l'aurait jamais montré à un client), même raisonnement que le
  `clientDisplayNameSnapshot` ajouté au Lot 8. **A cassé un test existant**
  (`test/root/supplier_shell_test.dart`, "logging out from the Profil
  tab") : le nouveau formulaire pousse le bouton "Déconnexion" hors-écran,
  corrigé avec `scrollUntilVisible` avant le tap — signal qu'un changement
  d'écran partagé peut avoir un effet de bord sur des tests d'autres lots,
  à vérifier systématiquement via la suite complète. Tests :
  `supplier_storefront_update_test.dart` (repository/controller),
  `supplier_account_screen_test.dart` (widget).
- **Lot 12** — Finances (résumé calculé + retraits) : nouvelle feature
  `supplier_finance/` — `PayoutRequest` (seul élément stocké, réutilise
  `MobileMoneyProvider` existant pour `method` plutôt qu'un nouvel enum),
  `SupplierFinancialSummary`/`SupplierFinanceSettings` (calculés à la
  volée). `compute_financial_summary.dart` (fonction pure, pattern
  `delivery_pricing.dart`) filtre elle-même les groupes `delivered` — testé
  directement sans `ProviderContainer`. `SupplierFinanceRepository`
  (`watchPayoutRequests`, `watchAllPayoutRequests` admin, `requestPayout`,
  `updatePayoutStatus` avec state machine `requested→processing/rejected`,
  `processing→paid/rejected`, `getSettings`/`updateSettings`) +
  `OrderRepository.+ watchAllOrders()`. Provider présentation
  `financialSummaryProvider` réutilise `supplierOrdersProvider`
  (`SupplierOrderView.myGroup`, la projection confidentialité du Lot 7)
  plutôt que de refiltrer les commandes lui-même. **Simplification
  documentée** : `platformCommissionSummaryProvider` (total plateforme,
  vue admin) utilise `AppConstants.defaultCommissionRatePercent`
  uniformément plutôt que le taux propre de chaque fournisseur — aucun
  écran ne permet aujourd'hui de faire diverger un taux du défaut, donc
  c'est correct en pratique, mais à corriger si `updateSettings` gagne un
  jour une UI. `SupplierFinanceController.requestPayout` **attend
  explicitement les données fraîches** (`.future` sur les providers
  sous-jacents) plutôt que de lire `financialSummaryProvider` via `ref.read`
  (qui peut être `null`/pas encore chargé si aucun écran ne l'a déjà
  observé) — piège à éviter pour toute validation cross-provider similaire.
  `supplier_finance_screen.dart` rempli (vue tiers avec bouton de demande de
  retrait + historique ; vue principal "ventes MTC directes" + section
  admin) ; nouvel écran `payout_review_queue_screen.dart` (staff admin
  uniquement, pas d'équivalent tiers — même logique que la file KYC du Lot
  3). **`OverflowBar` utilisé dès le départ** pour la rangée de boutons de
  la tuile de révision (leçon du Lot 10 appliquée préventivement — aucun
  bug de layout cette fois). Tests : `compute_financial_summary_test.dart`
  (fonction pure), `payout_flow_test.dart` (repository/controller),
  `supplier_finance_screen_test.dart` (widget, tiers + principal/admin).
- **Lot 13** (dernier lot) — Centre de notifications in-app : nouvelle
  feature `notifications/` — `AppNotification{id, userId, type, title,
  body, createdAt, isRead}`, `NotificationRepository`
  (`watchForUser`/`add`/`markRead`/`markAllRead`). `userId` est soit un
  `AppUser.id` littéral (client, ou fournisseur tiers dont l'id coïncide
  avec le `supplierId`), soit le `supplierId` MTC partagé pour le staff —
  donc `operatingSupplierIdProvider` sert directement de clé de lecture
  côté fournisseur, sans branchement supplémentaire. Écran
  `notification_center_screen.dart` + cloche avec badge non-lus sur
  l'AppBar du "Tableau de bord" (mirrorée `/supplier-tiers/notifications` +
  `/supplier-principal/notifications`, même schéma que la review
  management du Lot 10). **Câblage des 5 hooks prévus, un par un** :
  `CheckoutController.placeOrder` → `newOrder` (un par groupe fournisseur
  de la commande, pas juste un) ; `ChatController.send*` → `newMessage`
  (nouveau `ChatRepository.getConversationById` ajouté pour résoudre le
  destinataire — l'autre côté de `senderId` — sans dépendre d'un provider
  déjà "chaud") ; `SupplierProductController.adjustStock` → `lowStock` (si
  stock résultant ≤ seuil, après re-lecture du produit) ;
  `KycReviewController.approve/reject` → `kycDecision` ;
  `SupplierFinanceController.reviewPayout` → `payoutDecision`
  (`SupplierFinanceRepository.updatePayoutStatus` modifié pour retourner
  l'enregistrement mis à jour plutôt que `void`, pour connaître le
  `supplierId` sans second appel). **Hook non prévu par le plan d'origine
  ajouté** : `ReviewController.submit` → `newReview` — ce type existait déjà
  dans l'enum `NotificationType` mais n'était câblé nulle part dans la
  liste des hooks du plan, ce qui l'aurait laissé mort ; câblé par
  cohérence avec les 5 autres. **Décision de scope volontaire** : l'entrée
  du centre de notifications n'a été ajoutée que côté fournisseur (cloche
  sur `SupplierHomeScreen`) — les 5 types du plan sont tous
  fournisseur/staff-facing par nature ; un `newMessage` à destination d'un
  client est bien stocké (`userId = clientId`) mais n'a pas d'UI cliente
  dédiée dans ce lot (le badge de non-lu du chat, Lot 8, couvre déjà cet
  usage côté client en pratique). Tests : `notification_flow_test.dart`
  (repository/controller de base), `notification_hooks_test.dart` (un test
  par hook, 6 au total), `notification_center_screen_test.dart` (widget).

## Hors scope explicite (rappel, voir le plan original pour le détail complet)

Annulation côté client, remboursement Mobile Money, suspension d'un
fournisseur déjà vérifié, multi-comptes société, moteur de promotions
complexe, re-consentement APDP sur changement de politique, expiration des
documents KYC, notifications push réelles, provisioning UI pour comptes
`supplierPrincipal`.
