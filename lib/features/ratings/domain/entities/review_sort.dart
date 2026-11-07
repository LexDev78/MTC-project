/// L'ordre des avis sur l'écran « Avis » d'un produit.
///
/// Le tri est fait en base, avant la pagination (`fetch_product_reviews`,
/// `0114`) : trié ici, il ne porterait que sur la page déjà chargée.
enum ReviewSort {
  recent('recent', 'Plus récents'),
  best('best', 'Mieux notés'),
  worst('worst', 'Moins bien notés'),
  withMedia('media', 'Avec photos');

  const ReviewSort(this.rpcValue, this.label);

  /// La valeur attendue par `p_sort`.
  final String rpcValue;

  /// Court : il partage sa ligne avec le titre « Avis clients ».
  final String label;
}
