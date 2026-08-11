# MTC — Mali Trade Connect

Application e-commerce et de traçage de livraison pour le Mali, façon AliBaba : les clients parcourent les produits de **fournisseurs tiers** ou du **fournisseur principal (MTC)** dans deux onglets isolés, commandent, choisissent le mode de livraison, suivent leur colis en direct sur une carte, discutent avec le fournisseur et le notent après achat.

## État de ce lot de travail

Cette passe livre les **fondations complètes** (architecture Clean, thème Mali, routing par rôle, authentification à 3 rôles) et **l'intégralité du parcours Client** :

- Catalogue à deux onglets isolés (Fournisseurs tiers / Fournisseur principal), recherche, filtres par catégorie
- Fiche produit, fiche fournisseur publique avec avis
- Favoris, panier
- Commande avec choix du mode de livraison par fournisseur (livraison directe ou via MTC moyennant un forfait)
- Suivi de livraison en direct sur carte OpenStreetMap (simulation de trajet en temps réel)
- Notation post-achat, avec recalcul automatique de la note du fournisseur (et de sa visibilité dans le catalogue)
- Messagerie intégrée avec un fournisseur
- Profil, adresses, paramètres (thème clair/sombre/système)

Les rôles **Fournisseur tiers** et **Fournisseur principal** disposent d'un tableau de bord minimal après connexion — la gestion des produits, du stock et des livraisons pour ces rôles est prévue pour une prochaine itération. L'architecture (repositories, entités) est déjà prête pour les accueillir.

Le backend est actuellement **simulé en mémoire** (données de démonstration réalistes, réinitialisées à chaque lancement). Chaque repository est défini par une interface de domaine ; y brancher Firebase (Auth, Firestore, Storage) plus tard ne nécessite de modifier que la couche `data/` de chaque fonctionnalité, sans toucher au domaine ni à l'interface utilisateur.

## Comptes de démonstration

Mot de passe commun : **`password123`**

| Identifiant | Rôle | Détails |
|---|---|---|
| `client1` | Client | Awa Traoré — a un favori, une commande livrée et une commande en cours de livraison |
| `client2` | Client | Moussa Diarra — a un panier pré-rempli, une commande livrée et une en cours de livraison |
| `fournisseur1` | Fournisseur tiers | Bogolan Bamako — identité **vérifiée**, visible dans le catalogue |
| `fournisseur2` | Fournisseur tiers | Artisanat Sikasso — vérification **en attente**, donc **masqué** du catalogue client (démontre la règle : la vérification et la note conditionnent la visibilité) |
| `agent1` | Fournisseur principal (MTC) | Compte agent |
| `admin1` | Fournisseur principal (MTC) | Compte administrateur |

## Architecture

Clean Architecture, feature-first : chaque fonctionnalité sous `lib/features/<nom>/` est découpée en `domain/` (entités + interfaces de repository, sans dépendance Flutter), `data/` (implémentations en mémoire), `presentation/` (providers Riverpod, contrôleurs, écrans, widgets).

- **État** : Riverpod (providers écrits à la main — `riverpod_generator` a été écarté car sa chaîne de dépendances transitive (`analyzer_plugin`) était incompatible avec la version d'`analyzer` disponible ; l'approche manuelle reste pleinement moderne et testable).
- **Routing** : `go_router`, avec redirection par rôle (`lib/app/router/route_guards.dart`) et navigation par onglets préservant leur pile (`StatefulShellRoute.indexedStack`).
- **Modèles** : `freezed` pour l'immuabilité, l'égalité structurelle et `copyWith`.
- **Carte** : `flutter_map` + tuiles OpenStreetMap (aucune clé API requise).
- **Thème** : Material 3, palette indigo/violet, boutons pilule et cartes arrondies (`lib/app/theme/`).

## Lancer le projet

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # génère les fichiers *.freezed.dart
flutter run
```

## Tests

```bash
flutter analyze
flutter test
```
