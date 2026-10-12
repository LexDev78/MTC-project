import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item.freezed.dart';
part 'cart_item.g.dart';

@freezed
class CartItem with _$CartItem {
  const factory CartItem({
    required String id,
    required String userId,
    required String productId,
    required String supplierId,
    required String productNameSnapshot,
    required int unitPriceFcfaSnapshot,
    required int quantity,
    required DateTime addedAt,

    /// Which variant was selected, if the product has variants — `null`
    /// for a variant-less product, or when the caller adds without
    /// choosing one (see `CartController.addProduct`'s default-variant
    /// fallback).
    String? variantId,
    String? variantNameSnapshot,
  }) = _CartItem;

  factory CartItem.fromJson(Map<String, dynamic> json) =>
      _$CartItemFromJson(json);
}
