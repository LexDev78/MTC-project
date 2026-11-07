/// A product's lifecycle in its supplier's own catalog management — distinct
/// from `isSupplierVerified` (which gates visibility based on the *account*,
/// not the listing). Only `active` products can ever appear in
/// `ProductRepository.watchProducts` (the client-facing query); every status
/// is visible in `watchMyProducts` (the supplier's own management view).
enum ProductStatus {
  /// Being prepared — never shown to clients, including on the supplier's
  /// own public storefront.
  draft,
  active,

  /// Temporarily hidden by the supplier (e.g. out of stock for a while)
  /// without losing the listing's history/reviews the way archiving would.
  paused,

  /// Soft-deleted — kept so past orders' snapshots still resolve, but gone
  /// from every catalog view, including the supplier's own by default.
  archived;

  String get label => switch (this) {
    ProductStatus.draft => 'Brouillon',
    ProductStatus.active => 'Actif',
    ProductStatus.paused => 'En pause',
    ProductStatus.archived => 'Archivé',
  };
}
