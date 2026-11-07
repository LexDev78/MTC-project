import 'package:freezed_annotation/freezed_annotation.dart';

/// Les tris de la feuille « Trier par » du kit, dans son ordre, avec la
/// pertinence (l'ordre de la recherche ou du catalogue) en tête.
enum ProductSortOption {
  relevance,
  priceAsc,
  priceDesc,
  newest,
  ratingDesc,
  nameAsc,
  nameDesc;

  String get label => switch (this) {
    ProductSortOption.relevance => 'Pertinence',
    ProductSortOption.priceAsc => 'Prix croissant',
    ProductSortOption.priceDesc => 'Prix décroissant',
    ProductSortOption.newest => 'Plus récents',
    ProductSortOption.ratingDesc => 'Mieux notés',
    ProductSortOption.nameAsc => 'De A à Z',
    ProductSortOption.nameDesc => 'De Z à A',
  };
}

enum ProductCategory {
  @JsonValue('textiles_bogolan')
  textilesBogolan,
  artisanat,
  electronique,
  alimentation,
  @JsonValue('materiaux_construction')
  materiauxConstruction,
  autre;

  String get label => switch (this) {
    ProductCategory.textilesBogolan => 'Textiles & Bogolan',
    ProductCategory.artisanat => 'Artisanat',
    ProductCategory.electronique => 'Électronique',
    ProductCategory.alimentation => 'Alimentation',
    ProductCategory.materiauxConstruction => 'Matériaux',
    ProductCategory.autre => 'Autre',
  };
}

/// Distinguishes which side of the catalog a product belongs to — mirrors
/// the two supplier-capable `UserRole` variants, kept separate from
/// `UserRole` because a product has no notion of "client".
enum SupplierType { tiers, principal }

/// Where a product is manufactured/sourced from — a client-facing filter
/// axis independent of [ProductCategory], since e.g. electronics can come
/// from China or Europe while textiles are typically local.
enum ProductRegion {
  chine,
  europe,
  @JsonValue('afrique_hors_mali')
  afriqueHorsMali,
  mali,
  autre;

  String get label => switch (this) {
    ProductRegion.chine => 'Chine',
    ProductRegion.europe => 'Europe',
    ProductRegion.afriqueHorsMali => 'Afrique (hors Mali)',
    ProductRegion.mali => 'Mali (local)',
    ProductRegion.autre => 'Autre',
  };
}
