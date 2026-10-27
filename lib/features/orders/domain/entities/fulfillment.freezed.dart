// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fulfillment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PickupPoint _$PickupPointFromJson(Map<String, dynamic> json) {
  return _PickupPoint.fromJson(json);
}

/// @nodoc
mixin _$PickupPoint {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  double get latitude => throw _privateConstructorUsedError;
  double get longitude => throw _privateConstructorUsedError;

  /// Serializes this PickupPoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PickupPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PickupPointCopyWith<PickupPoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PickupPointCopyWith<$Res> {
  factory $PickupPointCopyWith(
    PickupPoint value,
    $Res Function(PickupPoint) then,
  ) = _$PickupPointCopyWithImpl<$Res, PickupPoint>;
  @useResult
  $Res call({
    String id,
    String name,
    String city,
    String address,
    double latitude,
    double longitude,
  });
}

/// @nodoc
class _$PickupPointCopyWithImpl<$Res, $Val extends PickupPoint>
    implements $PickupPointCopyWith<$Res> {
  _$PickupPointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PickupPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? city = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            latitude: null == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double,
            longitude: null == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PickupPointImplCopyWith<$Res>
    implements $PickupPointCopyWith<$Res> {
  factory _$$PickupPointImplCopyWith(
    _$PickupPointImpl value,
    $Res Function(_$PickupPointImpl) then,
  ) = __$$PickupPointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String city,
    String address,
    double latitude,
    double longitude,
  });
}

/// @nodoc
class __$$PickupPointImplCopyWithImpl<$Res>
    extends _$PickupPointCopyWithImpl<$Res, _$PickupPointImpl>
    implements _$$PickupPointImplCopyWith<$Res> {
  __$$PickupPointImplCopyWithImpl(
    _$PickupPointImpl _value,
    $Res Function(_$PickupPointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PickupPoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? city = null,
    Object? address = null,
    Object? latitude = null,
    Object? longitude = null,
  }) {
    return _then(
      _$PickupPointImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        latitude: null == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double,
        longitude: null == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$PickupPointImpl implements _PickupPoint {
  const _$PickupPointImpl({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory _$PickupPointImpl.fromJson(Map<String, dynamic> json) =>
      _$$PickupPointImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String city;
  @override
  final String address;
  @override
  final double latitude;
  @override
  final double longitude;

  @override
  String toString() {
    return 'PickupPoint(id: $id, name: $name, city: $city, address: $address, latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PickupPointImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, city, address, latitude, longitude);

  /// Create a copy of PickupPoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PickupPointImplCopyWith<_$PickupPointImpl> get copyWith =>
      __$$PickupPointImplCopyWithImpl<_$PickupPointImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PickupPointImplToJson(this);
  }
}

abstract class _PickupPoint implements PickupPoint {
  const factory _PickupPoint({
    required final String id,
    required final String name,
    required final String city,
    required final String address,
    required final double latitude,
    required final double longitude,
  }) = _$PickupPointImpl;

  factory _PickupPoint.fromJson(Map<String, dynamic> json) =
      _$PickupPointImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  String get city;
  @override
  String get address;
  @override
  double get latitude;
  @override
  double get longitude;

  /// Create a copy of PickupPoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PickupPointImplCopyWith<_$PickupPointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
