// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CartItem {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  String get productNameSnapshot => throw _privateConstructorUsedError;
  int get unitPriceFcfaSnapshot => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  DateTime get addedAt => throw _privateConstructorUsedError;

  /// Create a copy of CartItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CartItemCopyWith<CartItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CartItemCopyWith<$Res> {
  factory $CartItemCopyWith(CartItem value, $Res Function(CartItem) then) =
      _$CartItemCopyWithImpl<$Res, CartItem>;
  @useResult
  $Res call({
    String id,
    String userId,
    String productId,
    String supplierId,
    String productNameSnapshot,
    int unitPriceFcfaSnapshot,
    int quantity,
    DateTime addedAt,
  });
}

/// @nodoc
class _$CartItemCopyWithImpl<$Res, $Val extends CartItem>
    implements $CartItemCopyWith<$Res> {
  _$CartItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CartItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? productId = null,
    Object? supplierId = null,
    Object? productNameSnapshot = null,
    Object? unitPriceFcfaSnapshot = null,
    Object? quantity = null,
    Object? addedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            productNameSnapshot: null == productNameSnapshot
                ? _value.productNameSnapshot
                : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            unitPriceFcfaSnapshot: null == unitPriceFcfaSnapshot
                ? _value.unitPriceFcfaSnapshot
                : unitPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            addedAt: null == addedAt
                ? _value.addedAt
                : addedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CartItemImplCopyWith<$Res>
    implements $CartItemCopyWith<$Res> {
  factory _$$CartItemImplCopyWith(
    _$CartItemImpl value,
    $Res Function(_$CartItemImpl) then,
  ) = __$$CartItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String productId,
    String supplierId,
    String productNameSnapshot,
    int unitPriceFcfaSnapshot,
    int quantity,
    DateTime addedAt,
  });
}

/// @nodoc
class __$$CartItemImplCopyWithImpl<$Res>
    extends _$CartItemCopyWithImpl<$Res, _$CartItemImpl>
    implements _$$CartItemImplCopyWith<$Res> {
  __$$CartItemImplCopyWithImpl(
    _$CartItemImpl _value,
    $Res Function(_$CartItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CartItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? productId = null,
    Object? supplierId = null,
    Object? productNameSnapshot = null,
    Object? unitPriceFcfaSnapshot = null,
    Object? quantity = null,
    Object? addedAt = null,
  }) {
    return _then(
      _$CartItemImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        productNameSnapshot: null == productNameSnapshot
            ? _value.productNameSnapshot
            : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        unitPriceFcfaSnapshot: null == unitPriceFcfaSnapshot
            ? _value.unitPriceFcfaSnapshot
            : unitPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        addedAt: null == addedAt
            ? _value.addedAt
            : addedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$CartItemImpl implements _CartItem {
  const _$CartItemImpl({
    required this.id,
    required this.userId,
    required this.productId,
    required this.supplierId,
    required this.productNameSnapshot,
    required this.unitPriceFcfaSnapshot,
    required this.quantity,
    required this.addedAt,
  });

  @override
  final String id;
  @override
  final String userId;
  @override
  final String productId;
  @override
  final String supplierId;
  @override
  final String productNameSnapshot;
  @override
  final int unitPriceFcfaSnapshot;
  @override
  final int quantity;
  @override
  final DateTime addedAt;

  @override
  String toString() {
    return 'CartItem(id: $id, userId: $userId, productId: $productId, supplierId: $supplierId, productNameSnapshot: $productNameSnapshot, unitPriceFcfaSnapshot: $unitPriceFcfaSnapshot, quantity: $quantity, addedAt: $addedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CartItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.productNameSnapshot, productNameSnapshot) ||
                other.productNameSnapshot == productNameSnapshot) &&
            (identical(other.unitPriceFcfaSnapshot, unitPriceFcfaSnapshot) ||
                other.unitPriceFcfaSnapshot == unitPriceFcfaSnapshot) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    productId,
    supplierId,
    productNameSnapshot,
    unitPriceFcfaSnapshot,
    quantity,
    addedAt,
  );

  /// Create a copy of CartItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CartItemImplCopyWith<_$CartItemImpl> get copyWith =>
      __$$CartItemImplCopyWithImpl<_$CartItemImpl>(this, _$identity);
}

abstract class _CartItem implements CartItem {
  const factory _CartItem({
    required final String id,
    required final String userId,
    required final String productId,
    required final String supplierId,
    required final String productNameSnapshot,
    required final int unitPriceFcfaSnapshot,
    required final int quantity,
    required final DateTime addedAt,
  }) = _$CartItemImpl;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get productId;
  @override
  String get supplierId;
  @override
  String get productNameSnapshot;
  @override
  int get unitPriceFcfaSnapshot;
  @override
  int get quantity;
  @override
  DateTime get addedAt;

  /// Create a copy of CartItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CartItemImplCopyWith<_$CartItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
