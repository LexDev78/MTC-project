// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stock_movement.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

StockMovement _$StockMovementFromJson(Map<String, dynamic> json) {
  return _StockMovement.fromJson(json);
}

/// @nodoc
mixin _$StockMovement {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  int get quantityDelta => throw _privateConstructorUsedError;
  StockMovementReason get reason => throw _privateConstructorUsedError;
  DateTime get occurredAt => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Which variant this movement targeted — `null` for a variant-less
  /// product's own stock.
  String? get variantId => throw _privateConstructorUsedError;

  /// Serializes this StockMovement to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StockMovementCopyWith<StockMovement> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StockMovementCopyWith<$Res> {
  factory $StockMovementCopyWith(
    StockMovement value,
    $Res Function(StockMovement) then,
  ) = _$StockMovementCopyWithImpl<$Res, StockMovement>;
  @useResult
  $Res call({
    String id,
    String productId,
    int quantityDelta,
    StockMovementReason reason,
    DateTime occurredAt,
    String? note,
    String? variantId,
  });
}

/// @nodoc
class _$StockMovementCopyWithImpl<$Res, $Val extends StockMovement>
    implements $StockMovementCopyWith<$Res> {
  _$StockMovementCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? quantityDelta = null,
    Object? reason = null,
    Object? occurredAt = null,
    Object? note = freezed,
    Object? variantId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            quantityDelta: null == quantityDelta
                ? _value.quantityDelta
                : quantityDelta // ignore: cast_nullable_to_non_nullable
                      as int,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as StockMovementReason,
            occurredAt: null == occurredAt
                ? _value.occurredAt
                : occurredAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
            variantId: freezed == variantId
                ? _value.variantId
                : variantId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StockMovementImplCopyWith<$Res>
    implements $StockMovementCopyWith<$Res> {
  factory _$$StockMovementImplCopyWith(
    _$StockMovementImpl value,
    $Res Function(_$StockMovementImpl) then,
  ) = __$$StockMovementImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    int quantityDelta,
    StockMovementReason reason,
    DateTime occurredAt,
    String? note,
    String? variantId,
  });
}

/// @nodoc
class __$$StockMovementImplCopyWithImpl<$Res>
    extends _$StockMovementCopyWithImpl<$Res, _$StockMovementImpl>
    implements _$$StockMovementImplCopyWith<$Res> {
  __$$StockMovementImplCopyWithImpl(
    _$StockMovementImpl _value,
    $Res Function(_$StockMovementImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? quantityDelta = null,
    Object? reason = null,
    Object? occurredAt = null,
    Object? note = freezed,
    Object? variantId = freezed,
  }) {
    return _then(
      _$StockMovementImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        quantityDelta: null == quantityDelta
            ? _value.quantityDelta
            : quantityDelta // ignore: cast_nullable_to_non_nullable
                  as int,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as StockMovementReason,
        occurredAt: null == occurredAt
            ? _value.occurredAt
            : occurredAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
        variantId: freezed == variantId
            ? _value.variantId
            : variantId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$StockMovementImpl implements _StockMovement {
  const _$StockMovementImpl({
    required this.id,
    required this.productId,
    required this.quantityDelta,
    required this.reason,
    required this.occurredAt,
    this.note,
    this.variantId,
  });

  factory _$StockMovementImpl.fromJson(Map<String, dynamic> json) =>
      _$$StockMovementImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;
  @override
  final int quantityDelta;
  @override
  final StockMovementReason reason;
  @override
  final DateTime occurredAt;
  @override
  final String? note;

  /// Which variant this movement targeted — `null` for a variant-less
  /// product's own stock.
  @override
  final String? variantId;

  @override
  String toString() {
    return 'StockMovement(id: $id, productId: $productId, quantityDelta: $quantityDelta, reason: $reason, occurredAt: $occurredAt, note: $note, variantId: $variantId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StockMovementImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.quantityDelta, quantityDelta) ||
                other.quantityDelta == quantityDelta) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.occurredAt, occurredAt) ||
                other.occurredAt == occurredAt) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.variantId, variantId) ||
                other.variantId == variantId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    quantityDelta,
    reason,
    occurredAt,
    note,
    variantId,
  );

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StockMovementImplCopyWith<_$StockMovementImpl> get copyWith =>
      __$$StockMovementImplCopyWithImpl<_$StockMovementImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$StockMovementImplToJson(this);
  }
}

abstract class _StockMovement implements StockMovement {
  const factory _StockMovement({
    required final String id,
    required final String productId,
    required final int quantityDelta,
    required final StockMovementReason reason,
    required final DateTime occurredAt,
    final String? note,
    final String? variantId,
  }) = _$StockMovementImpl;

  factory _StockMovement.fromJson(Map<String, dynamic> json) =
      _$StockMovementImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;
  @override
  int get quantityDelta;
  @override
  StockMovementReason get reason;
  @override
  DateTime get occurredAt;
  @override
  String? get note;

  /// Which variant this movement targeted — `null` for a variant-less
  /// product's own stock.
  @override
  String? get variantId;

  /// Create a copy of StockMovement
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StockMovementImplCopyWith<_$StockMovementImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
