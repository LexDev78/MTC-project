// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_characteristic_type.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductCharacteristicType _$ProductCharacteristicTypeFromJson(
  Map<String, dynamic> json,
) {
  return _ProductCharacteristicType.fromJson(json);
}

/// @nodoc
mixin _$ProductCharacteristicType {
  String get id => throw _privateConstructorUsedError;
  String get label => throw _privateConstructorUsedError;
  CharacteristicTypeStatus get status => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String? get proposedBySupplierId => throw _privateConstructorUsedError;
  String? get reviewedByStaffId => throw _privateConstructorUsedError;
  DateTime? get reviewedAt => throw _privateConstructorUsedError;
  String? get rejectionReason => throw _privateConstructorUsedError;

  /// Serializes this ProductCharacteristicType to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductCharacteristicType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCharacteristicTypeCopyWith<ProductCharacteristicType> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCharacteristicTypeCopyWith<$Res> {
  factory $ProductCharacteristicTypeCopyWith(
    ProductCharacteristicType value,
    $Res Function(ProductCharacteristicType) then,
  ) = _$ProductCharacteristicTypeCopyWithImpl<$Res, ProductCharacteristicType>;
  @useResult
  $Res call({
    String id,
    String label,
    CharacteristicTypeStatus status,
    DateTime createdAt,
    String? proposedBySupplierId,
    String? reviewedByStaffId,
    DateTime? reviewedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class _$ProductCharacteristicTypeCopyWithImpl<
  $Res,
  $Val extends ProductCharacteristicType
>
    implements $ProductCharacteristicTypeCopyWith<$Res> {
  _$ProductCharacteristicTypeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductCharacteristicType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? status = null,
    Object? createdAt = null,
    Object? proposedBySupplierId = freezed,
    Object? reviewedByStaffId = freezed,
    Object? reviewedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            label: null == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as CharacteristicTypeStatus,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            proposedBySupplierId: freezed == proposedBySupplierId
                ? _value.proposedBySupplierId
                : proposedBySupplierId // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedByStaffId: freezed == reviewedByStaffId
                ? _value.reviewedByStaffId
                : reviewedByStaffId // ignore: cast_nullable_to_non_nullable
                      as String?,
            reviewedAt: freezed == reviewedAt
                ? _value.reviewedAt
                : reviewedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            rejectionReason: freezed == rejectionReason
                ? _value.rejectionReason
                : rejectionReason // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductCharacteristicTypeImplCopyWith<$Res>
    implements $ProductCharacteristicTypeCopyWith<$Res> {
  factory _$$ProductCharacteristicTypeImplCopyWith(
    _$ProductCharacteristicTypeImpl value,
    $Res Function(_$ProductCharacteristicTypeImpl) then,
  ) = __$$ProductCharacteristicTypeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String label,
    CharacteristicTypeStatus status,
    DateTime createdAt,
    String? proposedBySupplierId,
    String? reviewedByStaffId,
    DateTime? reviewedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class __$$ProductCharacteristicTypeImplCopyWithImpl<$Res>
    extends
        _$ProductCharacteristicTypeCopyWithImpl<
          $Res,
          _$ProductCharacteristicTypeImpl
        >
    implements _$$ProductCharacteristicTypeImplCopyWith<$Res> {
  __$$ProductCharacteristicTypeImplCopyWithImpl(
    _$ProductCharacteristicTypeImpl _value,
    $Res Function(_$ProductCharacteristicTypeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductCharacteristicType
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? status = null,
    Object? createdAt = null,
    Object? proposedBySupplierId = freezed,
    Object? reviewedByStaffId = freezed,
    Object? reviewedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _$ProductCharacteristicTypeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        label: null == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as CharacteristicTypeStatus,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        proposedBySupplierId: freezed == proposedBySupplierId
            ? _value.proposedBySupplierId
            : proposedBySupplierId // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedByStaffId: freezed == reviewedByStaffId
            ? _value.reviewedByStaffId
            : reviewedByStaffId // ignore: cast_nullable_to_non_nullable
                  as String?,
        reviewedAt: freezed == reviewedAt
            ? _value.reviewedAt
            : reviewedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        rejectionReason: freezed == rejectionReason
            ? _value.rejectionReason
            : rejectionReason // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductCharacteristicTypeImpl implements _ProductCharacteristicType {
  const _$ProductCharacteristicTypeImpl({
    required this.id,
    required this.label,
    required this.status,
    required this.createdAt,
    this.proposedBySupplierId,
    this.reviewedByStaffId,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory _$ProductCharacteristicTypeImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductCharacteristicTypeImplFromJson(json);

  @override
  final String id;
  @override
  final String label;
  @override
  final CharacteristicTypeStatus status;
  @override
  final DateTime createdAt;
  @override
  final String? proposedBySupplierId;
  @override
  final String? reviewedByStaffId;
  @override
  final DateTime? reviewedAt;
  @override
  final String? rejectionReason;

  @override
  String toString() {
    return 'ProductCharacteristicType(id: $id, label: $label, status: $status, createdAt: $createdAt, proposedBySupplierId: $proposedBySupplierId, reviewedByStaffId: $reviewedByStaffId, reviewedAt: $reviewedAt, rejectionReason: $rejectionReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductCharacteristicTypeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.proposedBySupplierId, proposedBySupplierId) ||
                other.proposedBySupplierId == proposedBySupplierId) &&
            (identical(other.reviewedByStaffId, reviewedByStaffId) ||
                other.reviewedByStaffId == reviewedByStaffId) &&
            (identical(other.reviewedAt, reviewedAt) ||
                other.reviewedAt == reviewedAt) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    label,
    status,
    createdAt,
    proposedBySupplierId,
    reviewedByStaffId,
    reviewedAt,
    rejectionReason,
  );

  /// Create a copy of ProductCharacteristicType
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductCharacteristicTypeImplCopyWith<_$ProductCharacteristicTypeImpl>
  get copyWith =>
      __$$ProductCharacteristicTypeImplCopyWithImpl<
        _$ProductCharacteristicTypeImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductCharacteristicTypeImplToJson(this);
  }
}

abstract class _ProductCharacteristicType implements ProductCharacteristicType {
  const factory _ProductCharacteristicType({
    required final String id,
    required final String label,
    required final CharacteristicTypeStatus status,
    required final DateTime createdAt,
    final String? proposedBySupplierId,
    final String? reviewedByStaffId,
    final DateTime? reviewedAt,
    final String? rejectionReason,
  }) = _$ProductCharacteristicTypeImpl;

  factory _ProductCharacteristicType.fromJson(Map<String, dynamic> json) =
      _$ProductCharacteristicTypeImpl.fromJson;

  @override
  String get id;
  @override
  String get label;
  @override
  CharacteristicTypeStatus get status;
  @override
  DateTime get createdAt;
  @override
  String? get proposedBySupplierId;
  @override
  String? get reviewedByStaffId;
  @override
  DateTime? get reviewedAt;
  @override
  String? get rejectionReason;

  /// Create a copy of ProductCharacteristicType
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductCharacteristicTypeImplCopyWith<_$ProductCharacteristicTypeImpl>
  get copyWith => throw _privateConstructorUsedError;
}
