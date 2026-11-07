import '../../../catalog/domain/entities/product.dart';

/// Pourquoi un produit apparaît dans le fil « Pour vous ».
///
/// Renvoyée par `get_recommended_products` (`0082`) en même temps que
/// l'identifiant : une suggestion sans justification est une liste de plus,
/// et le client n'a aucun moyen de juger si elle le concerne. L'ordre des
/// valeurs suit celui des sources côté base, du plus personnel au plus
/// générique.
enum SuggestionReason {
  /// Les catégories que la personne consulte, ouvre ou met en favori.
  affinity,

  /// « Souvent acheté avec » ce qu'elle a déjà commandé.
  coPurchase,

  /// Bien noté dans sa ville.
  local,

  /// Remise en cours.
  promo,

  /// Le filet : les mieux notés du catalogue. C'est ce que voit un compte
  /// neuf, qui n'a encore ni activité, ni commande, ni adresse.
  popular;

  /// La valeur telle que la base la renvoie. `switch` exhaustif plutôt que
  /// `name` : les deux côtés doivent pouvoir évoluer séparément, et un
  /// renommage Dart ne doit pas casser silencieusement la correspondance.
  static SuggestionReason? fromDb(String value) => switch (value) {
    'affinity' => SuggestionReason.affinity,
    'copurchase' => SuggestionReason.coPurchase,
    'local' => SuggestionReason.local,
    'promo' => SuggestionReason.promo,
    'popular' => SuggestionReason.popular,
    // Une source ajoutée en base et pas encore connue de l'app : le produit
    // reste suggéré, sans libellé, plutôt que de faire échouer tout le fil.
    _ => null,
  };

  /// Le texte affiché au-dessus du groupe. Au présent et à la deuxième
  /// personne : c'est une explication adressée au client, pas un nom de
  /// catégorie technique.
  String get label => switch (this) {
    SuggestionReason.affinity => 'D’après ce que vous consultez',
    SuggestionReason.coPurchase => 'Souvent acheté avec vos commandes',
    SuggestionReason.local => 'Bien noté près de vous',
    SuggestionReason.promo => 'En promotion en ce moment',
    SuggestionReason.popular => 'Les mieux notés du catalogue',
  };
}

/// Un produit suggéré, avec sa justification.
///
/// Un `record` plutôt qu'une entité `freezed`, pour la même raison que
/// `ProductStats` (`product_repository.dart`) : deux champs dont l'un est
/// déjà une entité, aucune logique propre, aucune sérialisation. Un
/// `freezed` ici ne servirait qu'à générer du code.
typedef ProductSuggestion = ({Product product, SuggestionReason? reason});
