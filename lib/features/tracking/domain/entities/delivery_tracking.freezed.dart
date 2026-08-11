// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delivery_tracking.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DeliveryTracking {
  String get orderId => throw _privateConstructorUsedError;
  String get groupId => throw _privateConstructorUsedError;
  LatLng get origin => throw _privateConstructorUsedError;
  LatLng get destination => throw _privateConstructorUsedError;
  LatLng get current => throw _privateConstructorUsedError;
  List<LatLng> get route => throw _privateConstructorUsedError;
  double get progressRatio => throw _privateConstructorUsedError;
  int get etaMinutes => throw _privateConstructorUsedError;
  TrackingStatus get status => throw _privateConstructorUsedError;

  /// Create a copy of DeliveryTracking
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeliveryTrackingCopyWith<DeliveryTracking> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeliveryTrackingCopyWith<$Res> {
  factory $DeliveryTrackingCopyWith(
    DeliveryTracking value,
    $Res Function(DeliveryTracking) then,
  ) = _$DeliveryTrackingCopyWithImpl<$Res, DeliveryTracking>;
  @useResult
  $Res call({
    String orderId,
    String groupId,
    LatLng origin,
    LatLng destination,
    LatLng current,
    List<LatLng> route,
    double progressRatio,
    int etaMinutes,
    TrackingStatus status,
  });
}

/// @nodoc
class _$DeliveryTrackingCopyWithImpl<$Res, $Val extends DeliveryTracking>
    implements $DeliveryTrackingCopyWith<$Res> {
  _$DeliveryTrackingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeliveryTracking
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderId = null,
    Object? groupId = null,
    Object? origin = null,
    Object? destination = null,
    Object? current = null,
    Object? route = null,
    Object? progressRatio = null,
    Object? etaMinutes = null,
    Object? status = null,
  }) {
    return _then(
      _value.copyWith(
            orderId: null == orderId
                ? _value.orderId
                : orderId // ignore: cast_nullable_to_non_nullable
                      as String,
            groupId: null == groupId
                ? _value.groupId
                : groupId // ignore: cast_nullable_to_non_nullable
                      as String,
            origin: null == origin
                ? _value.origin
                : origin // ignore: cast_nullable_to_non_nullable
                      as LatLng,
            destination: null == destination
                ? _value.destination
                : destination // ignore: cast_nullable_to_non_nullable
                      as LatLng,
            current: null == current
                ? _value.current
                : current // ignore: cast_nullable_to_non_nullable
                      as LatLng,
            route: null == route
                ? _value.route
                : route // ignore: cast_nullable_to_non_nullable
                      as List<LatLng>,
            progressRatio: null == progressRatio
                ? _value.progressRatio
                : progressRatio // ignore: cast_nullable_to_non_nullable
                      as double,
            etaMinutes: null == etaMinutes
                ? _value.etaMinutes
                : etaMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as TrackingStatus,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeliveryTrackingImplCopyWith<$Res>
    implements $DeliveryTrackingCopyWith<$Res> {
  factory _$$DeliveryTrackingImplCopyWith(
    _$DeliveryTrackingImpl value,
    $Res Function(_$DeliveryTrackingImpl) then,
  ) = __$$DeliveryTrackingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String orderId,
    String groupId,
    LatLng origin,
    LatLng destination,
    LatLng current,
    List<LatLng> route,
    double progressRatio,
    int etaMinutes,
    TrackingStatus status,
  });
}

/// @nodoc
class __$$DeliveryTrackingImplCopyWithImpl<$Res>
    extends _$DeliveryTrackingCopyWithImpl<$Res, _$DeliveryTrackingImpl>
    implements _$$DeliveryTrackingImplCopyWith<$Res> {
  __$$DeliveryTrackingImplCopyWithImpl(
    _$DeliveryTrackingImpl _value,
    $Res Function(_$DeliveryTrackingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeliveryTracking
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderId = null,
    Object? groupId = null,
    Object? origin = null,
    Object? destination = null,
    Object? current = null,
    Object? route = null,
    Object? progressRatio = null,
    Object? etaMinutes = null,
    Object? status = null,
  }) {
    return _then(
      _$DeliveryTrackingImpl(
        orderId: null == orderId
            ? _value.orderId
            : orderId // ignore: cast_nullable_to_non_nullable
                  as String,
        groupId: null == groupId
            ? _value.groupId
            : groupId // ignore: cast_nullable_to_non_nullable
                  as String,
        origin: null == origin
            ? _value.origin
            : origin // ignore: cast_nullable_to_non_nullable
                  as LatLng,
        destination: null == destination
            ? _value.destination
            : destination // ignore: cast_nullable_to_non_nullable
                  as LatLng,
        current: null == current
            ? _value.current
            : current // ignore: cast_nullable_to_non_nullable
                  as LatLng,
        route: null == route
            ? _value._route
            : route // ignore: cast_nullable_to_non_nullable
                  as List<LatLng>,
        progressRatio: null == progressRatio
            ? _value.progressRatio
            : progressRatio // ignore: cast_nullable_to_non_nullable
                  as double,
        etaMinutes: null == etaMinutes
            ? _value.etaMinutes
            : etaMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as TrackingStatus,
      ),
    );
  }
}

/// @nodoc

class _$DeliveryTrackingImpl implements _DeliveryTracking {
  const _$DeliveryTrackingImpl({
    required this.orderId,
    required this.groupId,
    required this.origin,
    required this.destination,
    required this.current,
    required final List<LatLng> route,
    required this.progressRatio,
    required this.etaMinutes,
    required this.status,
  }) : _route = route;

  @override
  final String orderId;
  @override
  final String groupId;
  @override
  final LatLng origin;
  @override
  final LatLng destination;
  @override
  final LatLng current;
  final List<LatLng> _route;
  @override
  List<LatLng> get route {
    if (_route is EqualUnmodifiableListView) return _route;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_route);
  }

  @override
  final double progressRatio;
  @override
  final int etaMinutes;
  @override
  final TrackingStatus status;

  @override
  String toString() {
    return 'DeliveryTracking(orderId: $orderId, groupId: $groupId, origin: $origin, destination: $destination, current: $current, route: $route, progressRatio: $progressRatio, etaMinutes: $etaMinutes, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeliveryTrackingImpl &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.groupId, groupId) || other.groupId == groupId) &&
            (identical(other.origin, origin) || other.origin == origin) &&
            (identical(other.destination, destination) ||
                other.destination == destination) &&
            (identical(other.current, current) || other.current == current) &&
            const DeepCollectionEquality().equals(other._route, _route) &&
            (identical(other.progressRatio, progressRatio) ||
                other.progressRatio == progressRatio) &&
            (identical(other.etaMinutes, etaMinutes) ||
                other.etaMinutes == etaMinutes) &&
            (identical(other.status, status) || other.status == status));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    orderId,
    groupId,
    origin,
    destination,
    current,
    const DeepCollectionEquality().hash(_route),
    progressRatio,
    etaMinutes,
    status,
  );

  /// Create a copy of DeliveryTracking
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeliveryTrackingImplCopyWith<_$DeliveryTrackingImpl> get copyWith =>
      __$$DeliveryTrackingImplCopyWithImpl<_$DeliveryTrackingImpl>(
        this,
        _$identity,
      );
}

abstract class _DeliveryTracking implements DeliveryTracking {
  const factory _DeliveryTracking({
    required final String orderId,
    required final String groupId,
    required final LatLng origin,
    required final LatLng destination,
    required final LatLng current,
    required final List<LatLng> route,
    required final double progressRatio,
    required final int etaMinutes,
    required final TrackingStatus status,
  }) = _$DeliveryTrackingImpl;

  @override
  String get orderId;
  @override
  String get groupId;
  @override
  LatLng get origin;
  @override
  LatLng get destination;
  @override
  LatLng get current;
  @override
  List<LatLng> get route;
  @override
  double get progressRatio;
  @override
  int get etaMinutes;
  @override
  TrackingStatus get status;

  /// Create a copy of DeliveryTracking
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeliveryTrackingImplCopyWith<_$DeliveryTrackingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
