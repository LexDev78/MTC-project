// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_characteristic.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductCharacteristicOption _$ProductCharacteristicOptionFromJson(
  Map<String, dynamic> json,
) {
  return _ProductCharacteristicOption.fromJson(json);
}

/// @nodoc
mixin _$ProductCharacteristicOption {
  String get id => throw _privateConstructorUsedError;
  String get characteristicId => throw _privateConstructorUsedError;
  String get value => throw _privateConstructorUsedError;
  int get priceDeltaFcfa => throw _privateConstructorUsedError;
  int get displayOrder => throw _privateConstructorUsedError;

  /// Serializes this ProductCharacteristicOption to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductCharacteristicOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCharacteristicOptionCopyWith<ProductCharacteristicOption>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCharacteristicOptionCopyWith<$Res> {
  factory $ProductCharacteristicOptionCopyWith(
    ProductCharacteristicOption value,
    $Res Function(ProductCharacteristicOption) then,
  ) =
      _$ProductCharacteristicOptionCopyWithImpl<
        $Res,
        ProductCharacteristicOption
      >;
  @useResult
  $Res call({
    String id,
    String characteristicId,
    String value,
    int priceDeltaFcfa,
    int displayOrder,
  });
}

/// @nodoc
class _$ProductCharacteristicOptionCopyWithImpl<
  $Res,
  $Val extends ProductCharacteristicOption
>
    implements $ProductCharacteristicOptionCopyWith<$Res> {
  _$ProductCharacteristicOptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductCharacteristicOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? characteristicId = null,
    Object? value = null,
    Object? priceDeltaFcfa = null,
    Object? displayOrder = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            characteristicId: null == characteristicId
                ? _value.characteristicId
                : characteristicId // ignore: cast_nullable_to_non_nullable
                      as String,
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
            priceDeltaFcfa: null == priceDeltaFcfa
                ? _value.priceDeltaFcfa
                : priceDeltaFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            displayOrder: null == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductCharacteristicOptionImplCopyWith<$Res>
    implements $ProductCharacteristicOptionCopyWith<$Res> {
  factory _$$ProductCharacteristicOptionImplCopyWith(
    _$ProductCharacteristicOptionImpl value,
    $Res Function(_$ProductCharacteristicOptionImpl) then,
  ) = __$$ProductCharacteristicOptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String characteristicId,
    String value,
    int priceDeltaFcfa,
    int displayOrder,
  });
}

/// @nodoc
class __$$ProductCharacteristicOptionImplCopyWithImpl<$Res>
    extends
        _$ProductCharacteristicOptionCopyWithImpl<
          $Res,
          _$ProductCharacteristicOptionImpl
        >
    implements _$$ProductCharacteristicOptionImplCopyWith<$Res> {
  __$$ProductCharacteristicOptionImplCopyWithImpl(
    _$ProductCharacteristicOptionImpl _value,
    $Res Function(_$ProductCharacteristicOptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductCharacteristicOption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? characteristicId = null,
    Object? value = null,
    Object? priceDeltaFcfa = null,
    Object? displayOrder = null,
  }) {
    return _then(
      _$ProductCharacteristicOptionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        characteristicId: null == characteristicId
            ? _value.characteristicId
            : characteristicId // ignore: cast_nullable_to_non_nullable
                  as String,
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
        priceDeltaFcfa: null == priceDeltaFcfa
            ? _value.priceDeltaFcfa
            : priceDeltaFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        displayOrder: null == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductCharacteristicOptionImpl
    implements _ProductCharacteristicOption {
  const _$ProductCharacteristicOptionImpl({
    required this.id,
    required this.characteristicId,
    required this.value,
    this.priceDeltaFcfa = 0,
    this.displayOrder = 0,
  });

  factory _$ProductCharacteristicOptionImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$ProductCharacteristicOptionImplFromJson(json);

  @override
  final String id;
  @override
  final String characteristicId;
  @override
  final String value;
  @override
  @JsonKey()
  final int priceDeltaFcfa;
  @override
  @JsonKey()
  final int displayOrder;

  @override
  String toString() {
    return 'ProductCharacteristicOption(id: $id, characteristicId: $characteristicId, value: $value, priceDeltaFcfa: $priceDeltaFcfa, displayOrder: $displayOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductCharacteristicOptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.characteristicId, characteristicId) ||
                other.characteristicId == characteristicId) &&
            (identical(other.value, value) || other.value == value) &&
            (identical(other.priceDeltaFcfa, priceDeltaFcfa) ||
                other.priceDeltaFcfa == priceDeltaFcfa) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    characteristicId,
    value,
    priceDeltaFcfa,
    displayOrder,
  );

  /// Create a copy of ProductCharacteristicOption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductCharacteristicOptionImplCopyWith<_$ProductCharacteristicOptionImpl>
  get copyWith =>
      __$$ProductCharacteristicOptionImplCopyWithImpl<
        _$ProductCharacteristicOptionImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductCharacteristicOptionImplToJson(this);
  }
}

abstract class _ProductCharacteristicOption
    implements ProductCharacteristicOption {
  const factory _ProductCharacteristicOption({
    required final String id,
    required final String characteristicId,
    required final String value,
    final int priceDeltaFcfa,
    final int displayOrder,
  }) = _$ProductCharacteristicOptionImpl;

  factory _ProductCharacteristicOption.fromJson(Map<String, dynamic> json) =
      _$ProductCharacteristicOptionImpl.fromJson;

  @override
  String get id;
  @override
  String get characteristicId;
  @override
  String get value;
  @override
  int get priceDeltaFcfa;
  @override
  int get displayOrder;

  /// Create a copy of ProductCharacteristicOption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductCharacteristicOptionImplCopyWith<_$ProductCharacteristicOptionImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ProductCharacteristic _$ProductCharacteristicFromJson(
  Map<String, dynamic> json,
) {
  return _ProductCharacteristic.fromJson(json);
}

/// @nodoc
mixin _$ProductCharacteristic {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  ProductCharacteristicType get type => throw _privateConstructorUsedError;
  int get displayOrder => throw _privateConstructorUsedError;
  List<ProductCharacteristicOption> get options =>
      throw _privateConstructorUsedError;

  /// Serializes this ProductCharacteristic to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCharacteristicCopyWith<ProductCharacteristic> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCharacteristicCopyWith<$Res> {
  factory $ProductCharacteristicCopyWith(
    ProductCharacteristic value,
    $Res Function(ProductCharacteristic) then,
  ) = _$ProductCharacteristicCopyWithImpl<$Res, ProductCharacteristic>;
  @useResult
  $Res call({
    String id,
    String productId,
    ProductCharacteristicType type,
    int displayOrder,
    List<ProductCharacteristicOption> options,
  });

  $ProductCharacteristicTypeCopyWith<$Res> get type;
}

/// @nodoc
class _$ProductCharacteristicCopyWithImpl<
  $Res,
  $Val extends ProductCharacteristic
>
    implements $ProductCharacteristicCopyWith<$Res> {
  _$ProductCharacteristicCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? type = null,
    Object? displayOrder = null,
    Object? options = null,
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
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as ProductCharacteristicType,
            displayOrder: null == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int,
            options: null == options
                ? _value.options
                : options // ignore: cast_nullable_to_non_nullable
                      as List<ProductCharacteristicOption>,
          )
          as $Val,
    );
  }

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProductCharacteristicTypeCopyWith<$Res> get type {
    return $ProductCharacteristicTypeCopyWith<$Res>(_value.type, (value) {
      return _then(_value.copyWith(type: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ProductCharacteristicImplCopyWith<$Res>
    implements $ProductCharacteristicCopyWith<$Res> {
  factory _$$ProductCharacteristicImplCopyWith(
    _$ProductCharacteristicImpl value,
    $Res Function(_$ProductCharacteristicImpl) then,
  ) = __$$ProductCharacteristicImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    ProductCharacteristicType type,
    int displayOrder,
    List<ProductCharacteristicOption> options,
  });

  @override
  $ProductCharacteristicTypeCopyWith<$Res> get type;
}

/// @nodoc
class __$$ProductCharacteristicImplCopyWithImpl<$Res>
    extends
        _$ProductCharacteristicCopyWithImpl<$Res, _$ProductCharacteristicImpl>
    implements _$$ProductCharacteristicImplCopyWith<$Res> {
  __$$ProductCharacteristicImplCopyWithImpl(
    _$ProductCharacteristicImpl _value,
    $Res Function(_$ProductCharacteristicImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? type = null,
    Object? displayOrder = null,
    Object? options = null,
  }) {
    return _then(
      _$ProductCharacteristicImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as ProductCharacteristicType,
        displayOrder: null == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        options: null == options
            ? _value._options
            : options // ignore: cast_nullable_to_non_nullable
                  as List<ProductCharacteristicOption>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductCharacteristicImpl implements _ProductCharacteristic {
  const _$ProductCharacteristicImpl({
    required this.id,
    required this.productId,
    required this.type,
    this.displayOrder = 0,
    final List<ProductCharacteristicOption> options = const [],
  }) : _options = options;

  factory _$ProductCharacteristicImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductCharacteristicImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;
  @override
  final ProductCharacteristicType type;
  @override
  @JsonKey()
  final int displayOrder;
  final List<ProductCharacteristicOption> _options;
  @override
  @JsonKey()
  List<ProductCharacteristicOption> get options {
    if (_options is EqualUnmodifiableListView) return _options;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_options);
  }

  @override
  String toString() {
    return 'ProductCharacteristic(id: $id, productId: $productId, type: $type, displayOrder: $displayOrder, options: $options)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductCharacteristicImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            const DeepCollectionEquality().equals(other._options, _options));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    type,
    displayOrder,
    const DeepCollectionEquality().hash(_options),
  );

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductCharacteristicImplCopyWith<_$ProductCharacteristicImpl>
  get copyWith =>
      __$$ProductCharacteristicImplCopyWithImpl<_$ProductCharacteristicImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductCharacteristicImplToJson(this);
  }
}

abstract class _ProductCharacteristic implements ProductCharacteristic {
  const factory _ProductCharacteristic({
    required final String id,
    required final String productId,
    required final ProductCharacteristicType type,
    final int displayOrder,
    final List<ProductCharacteristicOption> options,
  }) = _$ProductCharacteristicImpl;

  factory _ProductCharacteristic.fromJson(Map<String, dynamic> json) =
      _$ProductCharacteristicImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;
  @override
  ProductCharacteristicType get type;
  @override
  int get displayOrder;
  @override
  List<ProductCharacteristicOption> get options;

  /// Create a copy of ProductCharacteristic
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductCharacteristicImplCopyWith<_$ProductCharacteristicImpl>
  get copyWith => throw _privateConstructorUsedError;
}
