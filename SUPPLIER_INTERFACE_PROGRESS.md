# Espace fournisseur — suivi d'avancement

Ce fichier est le point de reprise pour la construction de l'espace fournisseur
(fournisseur tiers société/individuel + fournisseur principal MTC). Le plan
d'origine, complet et détaillé (contexte, principes d'architecture, séquence
des 13 lots), est dans `/Users/solomon/.claude/plans/structured-inventing-dewdrop.md`
— **le lire en premier** si le contexte ci-dessous ne suffit pas.

**État au 2026-08-13** : Lots 1 à 7 terminés (analyzer propre, 114 tests
verts). Lots 8 à 13 restants. Reprendre au Lot 8.

## Comment reprendre

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

## Fait (Lots 1-7)

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

## À faire (Lots 8-13, détail complet dans le plan original)

### Lot 8 — Messagerie côté fournisseur (PROCHAIN)
- `ChatConversation.unreadCount` → `unreadCountClient` + `unreadCountSupplier`
  (actuellement le compteur n'incrémente QUE côté client — un fournisseur
  n'aurait jamais de badge non-lu).
- `ChatRepository.watchConversationsForSupplier(supplierId)` (nouveau,
  symétrique de `watchConversationsForUser`).
- `enum ChatParticipant{client,supplier}`, `markConversationRead` conscient
  du côté qui lit.
- Remplir le stub `supplier_conversation_list_screen.dart` (liste des
  conversations, réutilise `ChatThreadScreen` tel quel — déjà agnostique du
  rôle, déjà branché via les routes du Lot 7).
- Adapter `chat_flow_test.dart` existant au renommage de champ.

### Lot 9 — Boîte de réception des commentaires produits
- `ProductComment.+ required supplierId` (résolu depuis `product.supplierId`) —
  **ripple sur 5-6 fichiers** : `comment_controller.dart`,
  `product_comments_modal.dart`, `product_comments_section.dart`,
  `comment_composer.dart`, l'appelant dans `product_detail_screen.dart`.
- `ProductCommentRepository.+ watchForSupplier(supplierId)`.
- Écran boîte de réception, accessible comme sous-vue de l'onglet "Produits"
  (pas de 7e onglet — décision déjà prise pour rester sur 6 branches).

### Lot 10 — Réponse du fournisseur aux avis
- `Review.+ supplierReply?/supplierRepliedAt?`.
- `ReviewRepository.+ reply({reviewId, supplierId, reply})`.
- Sous-vue de l'onglet "Profil". `supplier_profile_screen.dart` (vitrine
  publique) affiche la réponse si présente.

### Lot 11 — Profil vitrine étendu
- Étendre `SupplierProfile` **en place** (pas de 3e entité séparée) :
  `description, bannerUrl, fullAddress, addressLatitude/Longitude,
  publicPhoneNumbers, deliveryZones, openingHoursLabel, isOpen`.
- `SupplierRepository.+ updateStorefront(...)`, `+ setOpen(...)`.
- Remplir le stub `supplier_account_screen.dart`.

### Lot 12 — Finances (résumé calculé + retraits)
- Nouvelle feature `supplier_finance/` : `PayoutRequest` (seul élément
  **stocké**), `SupplierFinancialSummary`/`SupplierFinanceSettings`
  (**calculés à la volée** depuis `OrderRepository`, jamais stockés en
  double).
- `compute_financial_summary.dart` (fonction pure) : `gross` = somme des
  `subtotalFcfa` des groupes `delivered` (jamais `deliveryFeeFcfa`, déjà 0
  en mode `selfDelivery`) ; `commission = gross * rate / 100` ; `net = gross
  - commission`.
- Pour le fournisseur principal (confirmé avec l'utilisateur : portail
  complet miroir) : vue "ventes MTC directes" (commission = 0) + section
  admin (`StaffRole.admin` uniquement, agent = opérationnel/admin = argent,
  confirmé) "retraits à valider" + total des commissions plateforme —
  nécessite `OrderRepository.+ watchAllOrders()` et
  `SupplierFinanceRepository.+ watchAllPayoutRequests()` (cross-fournisseurs,
  admin only).
- Remplir le stub `supplier_finance_screen.dart`.

### Lot 13 — Centre de notifications in-app
- Scope réduit : liste in-app, pas de push réel.
- Nouvelle feature `notifications/`.
- Câblage rétroactif (petits hooks indépendants, lot le plus "étalé") dans :
  `CheckoutController.placeOrder`, `ChatController.send*`,
  `SupplierProductController.adjustStock` (si stock ≤ seuil),
  `KycReviewController.approve/reject`, contrôleur de retrait staff (Lot 12).
- Envisager de scinder en 13a (entité+repo+écran vide) et 13b (câblage des
  hooks un par un).

## Hors scope explicite (rappel, voir le plan original pour le détail complet)

Annulation côté client, remboursement Mobile Money, suspension d'un
fournisseur déjà vérifié, multi-comptes société, moteur de promotions
complexe, re-consentement APDP sur changement de politique, expiration des
documents KYC, notifications push réelles, provisioning UI pour comptes
`supplierPrincipal`.
