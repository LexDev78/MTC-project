import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

/// MTC's home-delivery fee — not a flat rate, since a courier's actual cost
/// scales with how far they drive, how heavy the load is, and how much
/// care/space it needs. Blends the three into a single per-supplier-group
/// fee, clamped to the [1000, 4000] FCFA bracket ops signed off on. This
/// fee is computed fresh per order/destination — it deliberately isn't
/// stored on `Product` (see `Product.weightKg`'s doc comment), so it never
/// gets baked into a product's own price.
int computeHomeDeliveryFeeFcfa({
  required double distanceKm,
  required double totalWeightKg,
  required Set<ProductCategory> categories,
}) {
  const base = 1000;
  const fcfaPerKm = 20.0;
  const fcfaPerKg = 25.0;
  const maxDistanceContribution = 1500.0;
  const maxWeightContribution = 1500.0;
  const minFeeFcfa = 1000;
  const maxFeeFcfa = 4000;

  final distanceContribution = (distanceKm * fcfaPerKm).clamp(
    0,
    maxDistanceContribution,
  );
  final weightContribution = (totalWeightKg * fcfaPerKg).clamp(
    0,
    maxWeightContribution,
  );
  // Handling/space surcharge — worst case across the group's categories,
  // not a sum, since it's one truck making one trip regardless of how many
  // different kinds of goods are on it.
  final categorySurcharge = categories.isEmpty
      ? 0
      : categories.map(_categorySurchargeFcfa).reduce((a, b) => a > b ? a : b);

  final raw = base + distanceContribution + weightContribution + categorySurcharge;
  return raw.round().clamp(minFeeFcfa, maxFeeFcfa);
}

int _categorySurchargeFcfa(ProductCategory category) => switch (category) {
  // Bulky, needs a truck rather than a moto.
  ProductCategory.materiauxConstruction => 500,
  // Fragile, handled with extra care.
  ProductCategory.electronique => 300,
  ProductCategory.alimentation => 200,
  ProductCategory.artisanat => 100,
  ProductCategory.textilesBogolan => 0,
  ProductCategory.autre => 100,
};
