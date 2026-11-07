import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_characteristic_type.freezed.dart';
part 'product_characteristic_type.g.dart';

/// Lifecycle of a characteristic type (couleur/stockage/taille/poids, or a
/// supplier-proposed one) in the shared dictionary every supplier draws
/// from — mirrors `KycReviewStatus`'s "single mutable record, no versioned
/// history" shape.
enum CharacteristicTypeStatus { pending, approved, rejected }

/// A type of characteristic a product can vary by (e.g. "Couleur"). The 4
/// starting types are seeded pre-approved (`proposedBySupplierId == null`);
/// anything else starts `pending` until a staff member approves or rejects
/// it (`CharacteristicTypeReviewController`, cloned from `KycReviewController`).
/// Once approved, a type is shared — usable by every supplier, not just
/// whoever proposed it.
@freezed
class ProductCharacteristicType with _$ProductCharacteristicType {
  const factory ProductCharacteristicType({
    required String id,
    required String label,
    required CharacteristicTypeStatus status,
    required DateTime createdAt,
    String? proposedBySupplierId,
    String? reviewedByStaffId,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) = _ProductCharacteristicType;

  factory ProductCharacteristicType.fromJson(Map<String, dynamic> json) =>
      _$ProductCharacteristicTypeFromJson(json);
}
