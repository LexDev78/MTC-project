// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'promotion.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Promotion _$PromotionFromJson(Map<String, dynamic> json) {
  return _Promotion.fromJson(json);
}

/// @nodoc
mixin _$Promotion {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  PromotionKind get kind => throw _privateConstructorUsedError;

  /// Un pourcentage (1 à 90) ou un montant en FCFA, selon [kind].
  int get value => throw _privateConstructorUsedError;

  /// Remise sur quantité : s'applique à partir de ce nombre d'unités.
  int get minQuantity => throw _privateConstructorUsedError;

  /// Fenêtre ouverte des deux côtés : `null` = déjà commencée / sans fin.
  DateTime? get startsAt => throw _privateConstructorUsedError;
  DateTime? get endsAt => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;

  /// Ce que le client lit sur la vignette (« Rentrée scolaire »).
  String? get label => throw _privateConstructorUsedError;

  /// Serializes this Promotion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Promotion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PromotionCopyWith<Promotion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromotionCopyWith<$Res> {
  factory $PromotionCopyWith(Promotion value, $Res Function(Promotion) then) =
      _$PromotionCopyWithImpl<$Res, Promotion>;
  @useResult
  $Res call({
    String id,
    String productId,
    PromotionKind kind,
    int value,
    int minQuantity,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isActive,
    String? label,
  });
}

/// @nodoc
class _$PromotionCopyWithImpl<$Res, $Val extends Promotion>
    implements $PromotionCopyWith<$Res> {
  _$PromotionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Promotion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? kind = null,
    Object? value = null,
    Object? minQuantity = null,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? isActive = null,
    Object? label = freezed,
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
            kind: null == kind
                ? _value.kind
                : kind // ignore: cast_nullable_to_non_nullable
                      as PromotionKind,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as int,
            minQuantity: null == minQuantity
                ? _value.minQuantity
                : minQuantity // ignore: cast_nullable_to_non_nullable
                      as int,
            startsAt: freezed == startsAt
                ? _value.startsAt
                : startsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endsAt: freezed == endsAt
                ? _value.endsAt
                : endsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromotionImplCopyWith<$Res>
    implements $PromotionCopyWith<$Res> {
  factory _$$PromotionImplCopyWith(
    _$PromotionImpl value,
    $Res Function(_$PromotionImpl) then,
  ) = __$$PromotionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    PromotionKind kind,
    int value,
    int minQuantity,
    DateTime? startsAt,
    DateTime? endsAt,
    bool isActive,
    String? label,
  });
}

/// @nodoc
class __$$PromotionImplCopyWithImpl<$Res>
    extends _$PromotionCopyWithImpl<$Res, _$PromotionImpl>
    implements _$$PromotionImplCopyWith<$Res> {
  __$$PromotionImplCopyWithImpl(
    _$PromotionImpl _value,
    $Res Function(_$PromotionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Promotion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? kind = null,
    Object? value = null,
    Object? minQuantity = null,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? isActive = null,
    Object? label = freezed,
  }) {
    return _then(
      _$PromotionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        kind: null == kind
            ? _value.kind
            : kind // ignore: cast_nullable_to_non_nullable
                  as PromotionKind,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as int,
        minQuantity: null == minQuantity
            ? _value.minQuantity
            : minQuantity // ignore: cast_nullable_to_non_nullable
                  as int,
        startsAt: freezed == startsAt
            ? _value.startsAt
            : startsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endsAt: freezed == endsAt
            ? _value.endsAt
            : endsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PromotionImpl implements _Promotion {
  const _$PromotionImpl({
    required this.id,
    required this.productId,
    required this.kind,
    required this.value,
    this.minQuantity = 1,
    this.startsAt,
    this.endsAt,
    this.isActive = true,
    this.label,
  });

  factory _$PromotionImpl.fromJson(Map<String, dynamic> json) =>
      _$$PromotionImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;
  @override
  final PromotionKind kind;

  /// Un pourcentage (1 à 90) ou un montant en FCFA, selon [kind].
  @override
  final int value;

  /// Remise sur quantité : s'applique à partir de ce nombre d'unités.
  @override
  @JsonKey()
  final int minQuantity;

  /// Fenêtre ouverte des deux côtés : `null` = déjà commencée / sans fin.
  @override
  final DateTime? startsAt;
  @override
  final DateTime? endsAt;
  @override
  @JsonKey()
  final bool isActive;

  /// Ce que le client lit sur la vignette (« Rentrée scolaire »).
  @override
  final String? label;

  @override
  String toString() {
    return 'Promotion(id: $id, productId: $productId, kind: $kind, value: $value, minQuantity: $minQuantity, startsAt: $startsAt, endsAt: $endsAt, isActive: $isActive, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromotionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.minQuantity, minQuantity) ||
                other.minQuantity == minQuantity) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.endsAt, endsAt) || other.endsAt == endsAt) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    kind,
    value,
    minQuantity,
    startsAt,
    endsAt,
    isActive,
    label,
  );

  /// Create a copy of Promotion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PromotionImplCopyWith<_$PromotionImpl> get copyWith =>
      __$$PromotionImplCopyWithImpl<_$PromotionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PromotionImplToJson(this);
  }
}

abstract class _Promotion implements Promotion {
  const factory _Promotion({
    required final String id,
    required final String productId,
    required final PromotionKind kind,
    required final int value,
    final int minQuantity,
    final DateTime? startsAt,
    final DateTime? endsAt,
    final bool isActive,
    final String? label,
  }) = _$PromotionImpl;

  factory _Promotion.fromJson(Map<String, dynamic> json) =
      _$PromotionImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;
  @override
  PromotionKind get kind;

  /// Un pourcentage (1 à 90) ou un montant en FCFA, selon [kind].
  @override
  int get value;

  /// Remise sur quantité : s'applique à partir de ce nombre d'unités.
  @override
  int get minQuantity;

  /// Fenêtre ouverte des deux côtés : `null` = déjà commencée / sans fin.
  @override
  DateTime? get startsAt;
  @override
  DateTime? get endsAt;
  @override
  bool get isActive;

  /// Ce que le client lit sur la vignette (« Rentrée scolaire »).
  @override
  String? get label;

  /// Create a copy of Promotion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PromotionImplCopyWith<_$PromotionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
