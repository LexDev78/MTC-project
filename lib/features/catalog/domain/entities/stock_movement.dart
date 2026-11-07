import 'package:freezed_annotation/freezed_annotation.dart';

part 'stock_movement.freezed.dart';
part 'stock_movement.g.dart';

enum StockMovementReason {
  /// A supplier-initiated correction from the product form or the stock
  /// adjustment sheet (restock, inventory correction, damage, etc. — the
  /// free-text [StockMovement.note] carries the specific reason).
  @JsonValue('manual_adjustment')
  manualAdjustment,

  /// Decremented automatically when an order is placed
  /// (`CheckoutController.placeOrder`).
  sale,
  restock,
  returned,
  correction;

  String get label => switch (this) {
    StockMovementReason.manualAdjustment => 'Ajustement manuel',
    StockMovementReason.sale => 'Vente',
    StockMovementReason.restock => 'Réapprovisionnement',
    StockMovementReason.returned => 'Retour',
    StockMovementReason.correction => 'Correction',
  };
}

/// One entry in a product's stock history — `ProductRepository.adjustStock`
/// is the single write path for every stock change (manual or from a sale),
/// so this log always reflects the full history, never just manual edits.
@freezed
class StockMovement with _$StockMovement {
  const factory StockMovement({
    required String id,
    required String productId,
    required int quantityDelta,
    required StockMovementReason reason,
    required DateTime occurredAt,
    String? note,

    /// Which variant this movement targeted — `null` for a variant-less
    /// product's own stock.
    String? variantId,
  }) = _StockMovement;

  factory StockMovement.fromJson(Map<String, dynamic> json) =>
      _$StockMovementFromJson(json);
}
