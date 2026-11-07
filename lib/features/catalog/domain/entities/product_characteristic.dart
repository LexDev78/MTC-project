import 'package:freezed_annotation/freezed_annotation.dart';

import 'product_characteristic_type.dart';

part 'product_characteristic.freezed.dart';
part 'product_characteristic.g.dart';

/// One selectable value of a [ProductCharacteristic] (e.g. "Noir" under
/// "Couleur") — [priceDeltaFcfa] is added to a variant's price for every
/// option it picks (see `ProductVariant.optionRefs`).
@freezed
class ProductCharacteristicOption with _$ProductCharacteristicOption {
  const factory ProductCharacteristicOption({
    required String id,
    required String characteristicId,
    required String value,
    @Default(0) int priceDeltaFcfa,
    @Default(0) int displayOrder,
  }) = _ProductCharacteristicOption;

  factory ProductCharacteristicOption.fromJson(Map<String, dynamic> json) =>
      _$ProductCharacteristicOptionFromJson(json);
}

/// One axis a product's variants combine over (e.g. "Couleur" with options
/// Noir/Blanc/Bleu). [type] is nested (not a bare id) so the label is
/// available everywhere a characteristic is rendered without a second
/// lookup — populated by `getById`'s nested select
/// (`characteristics:product_characteristics(*, type:product_characteristic_types(*), ...)`),
/// aliased to `type`.
@freezed
class ProductCharacteristic with _$ProductCharacteristic {
  const factory ProductCharacteristic({
    required String id,
    required String productId,
    required ProductCharacteristicType type,
    @Default(0) int displayOrder,
    @Default([]) List<ProductCharacteristicOption> options,
  }) = _ProductCharacteristic;

  factory ProductCharacteristic.fromJson(Map<String, dynamic> json) =>
      _$ProductCharacteristicFromJson(json);
}
