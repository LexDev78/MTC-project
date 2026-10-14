/// Ce qu'une recherche par photo rend : des identifiants de produits, classés,
/// et ce qu'il reste d'appels aujourd'hui.
///
/// Des identifiants et non des produits : la fonction edge ne renvoie que
/// cela, et l'app les résout par ses lectures habituelles — qui appliquent
/// déjà la RLS et les règles d'affichage du catalogue. Un produit retiré de
/// la vente entre l'indexation et la recherche disparaît donc de lui-même.
typedef VisualMatch = ({String productId, double similarity});

class VisualSearchResult {
  const VisualSearchResult({
    required this.matches,
    required this.remaining,
    this.queryId,
  });

  final List<VisualMatch> matches;

  /// L'identifiant de la recherche conservée côté serveur (`0086`), ou
  /// `null` si la conservation a échoué ou traîné.
  ///
  /// Il sert à une seule chose : signaler **quel** résultat a été ouvert.
  /// C'est l'étiquette du futur jeu d'entraînement — la donnée la plus
  /// difficile à obtenir, parce qu'elle ne se déduit d'aucune autre. Son
  /// absence ne gêne rien d'autre que cette collecte.
  final String? queryId;

  /// Appels restants aujourd'hui. Affiché au client plutôt que de le laisser
  /// découvrir le plafond en se faisant refuser.
  final int remaining;
}

/// Un refus que l'écran doit expliquer, pas une panne.
///
/// Trois cas distincts — plafond atteint, modèle indisponible, photo
/// refusée — et un seul message utile par cas : « réessayez » n'aide pas
/// quelqu'un qui a épuisé son quota.
class VisualSearchException implements Exception {
  const VisualSearchException(this.message, {this.quotaExhausted = false});

  final String message;
  final bool quotaExhausted;

  @override
  String toString() => message;
}
