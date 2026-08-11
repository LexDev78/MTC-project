import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item.freezed.dart';

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
  }) = _CartItem;
}
