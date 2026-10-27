// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payout_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

PayoutRequest _$PayoutRequestFromJson(Map<String, dynamic> json) {
  return _PayoutRequest.fromJson(json);
}

/// @nodoc
mixin _$PayoutRequest {
  String get id => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  int get amountFcfa => throw _privateConstructorUsedError;
  PayoutStatus get status => throw _privateConstructorUsedError;
  DateTime get requestedAt => throw _privateConstructorUsedError;

  /// Reuses `MobileMoneyProvider` rather than a new payout-specific
  /// enum — same two operators, no reason to duplicate.
  MobileMoneyProvider get method => throw _privateConstructorUsedError;
  String get payoutDestination => throw _privateConstructorUsedError;
  DateTime? get processedAt => throw _privateConstructorUsedError;
  String? get rejectionReason => throw _privateConstructorUsedError;

  /// Serializes this PayoutRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of PayoutRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PayoutRequestCopyWith<PayoutRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PayoutRequestCopyWith<$Res> {
  factory $PayoutRequestCopyWith(
    PayoutRequest value,
    $Res Function(PayoutRequest) then,
  ) = _$PayoutRequestCopyWithImpl<$Res, PayoutRequest>;
  @useResult
  $Res call({
    String id,
    String supplierId,
    int amountFcfa,
    PayoutStatus status,
    DateTime requestedAt,
    MobileMoneyProvider method,
    String payoutDestination,
    DateTime? processedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class _$PayoutRequestCopyWithImpl<$Res, $Val extends PayoutRequest>
    implements $PayoutRequestCopyWith<$Res> {
  _$PayoutRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PayoutRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? amountFcfa = null,
    Object? status = null,
    Object? requestedAt = null,
    Object? method = null,
    Object? payoutDestination = null,
    Object? processedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            amountFcfa: null == amountFcfa
                ? _value.amountFcfa
                : amountFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as PayoutStatus,
            requestedAt: null == requestedAt
                ? _value.requestedAt
                : requestedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            method: null == method
                ? _value.method
                : method // ignore: cast_nullable_to_non_nullable
                      as MobileMoneyProvider,
            payoutDestination: null == payoutDestination
                ? _value.payoutDestination
                : payoutDestination // ignore: cast_nullable_to_non_nullable
                      as String,
            processedAt: freezed == processedAt
                ? _value.processedAt
                : processedAt // ignore: cast_nullable_to_non_nullable
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
abstract class _$$PayoutRequestImplCopyWith<$Res>
    implements $PayoutRequestCopyWith<$Res> {
  factory _$$PayoutRequestImplCopyWith(
    _$PayoutRequestImpl value,
    $Res Function(_$PayoutRequestImpl) then,
  ) = __$$PayoutRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String supplierId,
    int amountFcfa,
    PayoutStatus status,
    DateTime requestedAt,
    MobileMoneyProvider method,
    String payoutDestination,
    DateTime? processedAt,
    String? rejectionReason,
  });
}

/// @nodoc
class __$$PayoutRequestImplCopyWithImpl<$Res>
    extends _$PayoutRequestCopyWithImpl<$Res, _$PayoutRequestImpl>
    implements _$$PayoutRequestImplCopyWith<$Res> {
  __$$PayoutRequestImplCopyWithImpl(
    _$PayoutRequestImpl _value,
    $Res Function(_$PayoutRequestImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PayoutRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? amountFcfa = null,
    Object? status = null,
    Object? requestedAt = null,
    Object? method = null,
    Object? payoutDestination = null,
    Object? processedAt = freezed,
    Object? rejectionReason = freezed,
  }) {
    return _then(
      _$PayoutRequestImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        amountFcfa: null == amountFcfa
            ? _value.amountFcfa
            : amountFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as PayoutStatus,
        requestedAt: null == requestedAt
            ? _value.requestedAt
            : requestedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        method: null == method
            ? _value.method
            : method // ignore: cast_nullable_to_non_nullable
                  as MobileMoneyProvider,
        payoutDestination: null == payoutDestination
            ? _value.payoutDestination
            : payoutDestination // ignore: cast_nullable_to_non_nullable
                  as String,
        processedAt: freezed == processedAt
            ? _value.processedAt
            : processedAt // ignore: cast_nullable_to_non_nullable
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
class _$PayoutRequestImpl implements _PayoutRequest {
  const _$PayoutRequestImpl({
    required this.id,
    required this.supplierId,
    required this.amountFcfa,
    required this.status,
    required this.requestedAt,
    required this.method,
    required this.payoutDestination,
    this.processedAt,
    this.rejectionReason,
  });

  factory _$PayoutRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$PayoutRequestImplFromJson(json);

  @override
  final String id;
  @override
  final String supplierId;
  @override
  final int amountFcfa;
  @override
  final PayoutStatus status;
  @override
  final DateTime requestedAt;

  /// Reuses `MobileMoneyProvider` rather than a new payout-specific
  /// enum — same two operators, no reason to duplicate.
  @override
  final MobileMoneyProvider method;
  @override
  final String payoutDestination;
  @override
  final DateTime? processedAt;
  @override
  final String? rejectionReason;

  @override
  String toString() {
    return 'PayoutRequest(id: $id, supplierId: $supplierId, amountFcfa: $amountFcfa, status: $status, requestedAt: $requestedAt, method: $method, payoutDestination: $payoutDestination, processedAt: $processedAt, rejectionReason: $rejectionReason)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PayoutRequestImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.amountFcfa, amountFcfa) ||
                other.amountFcfa == amountFcfa) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.requestedAt, requestedAt) ||
                other.requestedAt == requestedAt) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.payoutDestination, payoutDestination) ||
                other.payoutDestination == payoutDestination) &&
            (identical(other.processedAt, processedAt) ||
                other.processedAt == processedAt) &&
            (identical(other.rejectionReason, rejectionReason) ||
                other.rejectionReason == rejectionReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    supplierId,
    amountFcfa,
    status,
    requestedAt,
    method,
    payoutDestination,
    processedAt,
    rejectionReason,
  );

  /// Create a copy of PayoutRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PayoutRequestImplCopyWith<_$PayoutRequestImpl> get copyWith =>
      __$$PayoutRequestImplCopyWithImpl<_$PayoutRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PayoutRequestImplToJson(this);
  }
}

abstract class _PayoutRequest implements PayoutRequest {
  const factory _PayoutRequest({
    required final String id,
    required final String supplierId,
    required final int amountFcfa,
    required final PayoutStatus status,
    required final DateTime requestedAt,
    required final MobileMoneyProvider method,
    required final String payoutDestination,
    final DateTime? processedAt,
    final String? rejectionReason,
  }) = _$PayoutRequestImpl;

  factory _PayoutRequest.fromJson(Map<String, dynamic> json) =
      _$PayoutRequestImpl.fromJson;

  @override
  String get id;
  @override
  String get supplierId;
  @override
  int get amountFcfa;
  @override
  PayoutStatus get status;
  @override
  DateTime get requestedAt;

  /// Reuses `MobileMoneyProvider` rather than a new payout-specific
  /// enum — same two operators, no reason to duplicate.
  @override
  MobileMoneyProvider get method;
  @override
  String get payoutDestination;
  @override
  DateTime? get processedAt;
  @override
  String? get rejectionReason;

  /// Create a copy of PayoutRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PayoutRequestImplCopyWith<_$PayoutRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
