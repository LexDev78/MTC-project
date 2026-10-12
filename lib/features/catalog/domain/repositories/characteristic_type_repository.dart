import '../entities/product_characteristic_type.dart';

/// Contract for the shared dictionary of characteristic types
/// (couleur/stockage/taille/poids + supplier proposals) every supplier
/// draws from when defining a product's variants. Cloned from
/// `SupplierKycRepository`'s "propose → staff reviews → approve/reject"
/// shape.
abstract interface class CharacteristicTypeRepository {
  /// Every `approved` type — what the supplier's characteristic picker and
  /// the client-facing swatch/chip labels draw from.
  Stream<List<ProductCharacteristicType>> watchApprovedTypes();

  /// Staff review queue: every `pending` proposal.
  Stream<List<ProductCharacteristicType>> watchQueue();

  /// Creates a new `pending` proposal under [supplierId]'s name. Visible
  /// only to that supplier and staff until a decision is made (see RLS on
  /// `product_characteristic_types`).
  Future<void> propose({required String supplierId, required String label});

  /// Only updates the type's own status/review fields — propagation (e.g.
  /// a notification to the proposer) is cross-repository orchestration
  /// that belongs in `CharacteristicTypeReviewController`, not here.
  Future<void> approve({required String id, required String staffId});

  Future<void> reject({
    required String id,
    required String staffId,
    required String reason,
  });
}
