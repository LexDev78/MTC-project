// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'courier_history.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$CourierHistoryEntry {
  String get deliveryId => throw _privateConstructorUsedError;

  /// Référence courte, citable au support sans lire 36 caractères.
  String get reference => throw _privateConstructorUsedError;
  DeliveryStatus get status => throw _privateConstructorUsedError;
  String get pickupCity => throw _privateConstructorUsedError;
  String get dropoffCity => throw _privateConstructorUsedError;
  int get itemCount => throw _privateConstructorUsedError;
  int get deliveryFeeFcfa => throw _privateConstructorUsedError;
  DateTime? get acceptedAt => throw _privateConstructorUsedError;
  DateTime? get pickedUpAt => throw _privateConstructorUsedError;
  DateTime? get deliveredAt => throw _privateConstructorUsedError;

  /// Notes reçues pour cette course, côté par côté — `null` quand ce côté
  /// n'a pas noté.
  int? get clientStars => throw _privateConstructorUsedError;
  int? get supplierStars => throw _privateConstructorUsedError;

  /// Create a copy of CourierHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierHistoryEntryCopyWith<CourierHistoryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierHistoryEntryCopyWith<$Res> {
  factory $CourierHistoryEntryCopyWith(
    CourierHistoryEntry value,
    $Res Function(CourierHistoryEntry) then,
  ) = _$CourierHistoryEntryCopyWithImpl<$Res, CourierHistoryEntry>;
  @useResult
  $Res call({
    String deliveryId,
    String reference,
    DeliveryStatus status,
    String pickupCity,
    String dropoffCity,
    int itemCount,
    int deliveryFeeFcfa,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    int? clientStars,
    int? supplierStars,
  });
}

/// @nodoc
class _$CourierHistoryEntryCopyWithImpl<$Res, $Val extends CourierHistoryEntry>
    implements $CourierHistoryEntryCopyWith<$Res> {
  _$CourierHistoryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deliveryId = null,
    Object? reference = null,
    Object? status = null,
    Object? pickupCity = null,
    Object? dropoffCity = null,
    Object? itemCount = null,
    Object? deliveryFeeFcfa = null,
    Object? acceptedAt = freezed,
    Object? pickedUpAt = freezed,
    Object? deliveredAt = freezed,
    Object? clientStars = freezed,
    Object? supplierStars = freezed,
  }) {
    return _then(
      _value.copyWith(
            deliveryId: null == deliveryId
                ? _value.deliveryId
                : deliveryId // ignore: cast_nullable_to_non_nullable
                      as String,
            reference: null == reference
                ? _value.reference
                : reference // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as DeliveryStatus,
            pickupCity: null == pickupCity
                ? _value.pickupCity
                : pickupCity // ignore: cast_nullable_to_non_nullable
                      as String,
            dropoffCity: null == dropoffCity
                ? _value.dropoffCity
                : dropoffCity // ignore: cast_nullable_to_non_nullable
                      as String,
            itemCount: null == itemCount
                ? _value.itemCount
                : itemCount // ignore: cast_nullable_to_non_nullable
                      as int,
            deliveryFeeFcfa: null == deliveryFeeFcfa
                ? _value.deliveryFeeFcfa
                : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            acceptedAt: freezed == acceptedAt
                ? _value.acceptedAt
                : acceptedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            pickedUpAt: freezed == pickedUpAt
                ? _value.pickedUpAt
                : pickedUpAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deliveredAt: freezed == deliveredAt
                ? _value.deliveredAt
                : deliveredAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            clientStars: freezed == clientStars
                ? _value.clientStars
                : clientStars // ignore: cast_nullable_to_non_nullable
                      as int?,
            supplierStars: freezed == supplierStars
                ? _value.supplierStars
                : supplierStars // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierHistoryEntryImplCopyWith<$Res>
    implements $CourierHistoryEntryCopyWith<$Res> {
  factory _$$CourierHistoryEntryImplCopyWith(
    _$CourierHistoryEntryImpl value,
    $Res Function(_$CourierHistoryEntryImpl) then,
  ) = __$$CourierHistoryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String deliveryId,
    String reference,
    DeliveryStatus status,
    String pickupCity,
    String dropoffCity,
    int itemCount,
    int deliveryFeeFcfa,
    DateTime? acceptedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    int? clientStars,
    int? supplierStars,
  });
}

/// @nodoc
class __$$CourierHistoryEntryImplCopyWithImpl<$Res>
    extends _$CourierHistoryEntryCopyWithImpl<$Res, _$CourierHistoryEntryImpl>
    implements _$$CourierHistoryEntryImplCopyWith<$Res> {
  __$$CourierHistoryEntryImplCopyWithImpl(
    _$CourierHistoryEntryImpl _value,
    $Res Function(_$CourierHistoryEntryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deliveryId = null,
    Object? reference = null,
    Object? status = null,
    Object? pickupCity = null,
    Object? dropoffCity = null,
    Object? itemCount = null,
    Object? deliveryFeeFcfa = null,
    Object? acceptedAt = freezed,
    Object? pickedUpAt = freezed,
    Object? deliveredAt = freezed,
    Object? clientStars = freezed,
    Object? supplierStars = freezed,
  }) {
    return _then(
      _$CourierHistoryEntryImpl(
        deliveryId: null == deliveryId
            ? _value.deliveryId
            : deliveryId // ignore: cast_nullable_to_non_nullable
                  as String,
        reference: null == reference
            ? _value.reference
            : reference // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as DeliveryStatus,
        pickupCity: null == pickupCity
            ? _value.pickupCity
            : pickupCity // ignore: cast_nullable_to_non_nullable
                  as String,
        dropoffCity: null == dropoffCity
            ? _value.dropoffCity
            : dropoffCity // ignore: cast_nullable_to_non_nullable
                  as String,
        itemCount: null == itemCount
            ? _value.itemCount
            : itemCount // ignore: cast_nullable_to_non_nullable
                  as int,
        deliveryFeeFcfa: null == deliveryFeeFcfa
            ? _value.deliveryFeeFcfa
            : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        acceptedAt: freezed == acceptedAt
            ? _value.acceptedAt
            : acceptedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        pickedUpAt: freezed == pickedUpAt
            ? _value.pickedUpAt
            : pickedUpAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deliveredAt: freezed == deliveredAt
            ? _value.deliveredAt
            : deliveredAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        clientStars: freezed == clientStars
            ? _value.clientStars
            : clientStars // ignore: cast_nullable_to_non_nullable
                  as int?,
        supplierStars: freezed == supplierStars
            ? _value.supplierStars
            : supplierStars // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$CourierHistoryEntryImpl implements _CourierHistoryEntry {
  const _$CourierHistoryEntryImpl({
    required this.deliveryId,
    required this.reference,
    required this.status,
    required this.pickupCity,
    required this.dropoffCity,
    required this.itemCount,
    required this.deliveryFeeFcfa,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.clientStars,
    this.supplierStars,
  });

  @override
  final String deliveryId;

  /// Référence courte, citable au support sans lire 36 caractères.
  @override
  final String reference;
  @override
  final DeliveryStatus status;
  @override
  final String pickupCity;
  @override
  final String dropoffCity;
  @override
  final int itemCount;
  @override
  final int deliveryFeeFcfa;
  @override
  final DateTime? acceptedAt;
  @override
  final DateTime? pickedUpAt;
  @override
  final DateTime? deliveredAt;

  /// Notes reçues pour cette course, côté par côté — `null` quand ce côté
  /// n'a pas noté.
  @override
  final int? clientStars;
  @override
  final int? supplierStars;

  @override
  String toString() {
    return 'CourierHistoryEntry(deliveryId: $deliveryId, reference: $reference, status: $status, pickupCity: $pickupCity, dropoffCity: $dropoffCity, itemCount: $itemCount, deliveryFeeFcfa: $deliveryFeeFcfa, acceptedAt: $acceptedAt, pickedUpAt: $pickedUpAt, deliveredAt: $deliveredAt, clientStars: $clientStars, supplierStars: $supplierStars)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierHistoryEntryImpl &&
            (identical(other.deliveryId, deliveryId) ||
                other.deliveryId == deliveryId) &&
            (identical(other.reference, reference) ||
                other.reference == reference) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.pickupCity, pickupCity) ||
                other.pickupCity == pickupCity) &&
            (identical(other.dropoffCity, dropoffCity) ||
                other.dropoffCity == dropoffCity) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount) &&
            (identical(other.deliveryFeeFcfa, deliveryFeeFcfa) ||
                other.deliveryFeeFcfa == deliveryFeeFcfa) &&
            (identical(other.acceptedAt, acceptedAt) ||
                other.acceptedAt == acceptedAt) &&
            (identical(other.pickedUpAt, pickedUpAt) ||
                other.pickedUpAt == pickedUpAt) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.clientStars, clientStars) ||
                other.clientStars == clientStars) &&
            (identical(other.supplierStars, supplierStars) ||
                other.supplierStars == supplierStars));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    deliveryId,
    reference,
    status,
    pickupCity,
    dropoffCity,
    itemCount,
    deliveryFeeFcfa,
    acceptedAt,
    pickedUpAt,
    deliveredAt,
    clientStars,
    supplierStars,
  );

  /// Create a copy of CourierHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierHistoryEntryImplCopyWith<_$CourierHistoryEntryImpl> get copyWith =>
      __$$CourierHistoryEntryImplCopyWithImpl<_$CourierHistoryEntryImpl>(
        this,
        _$identity,
      );
}

abstract class _CourierHistoryEntry implements CourierHistoryEntry {
  const factory _CourierHistoryEntry({
    required final String deliveryId,
    required final String reference,
    required final DeliveryStatus status,
    required final String pickupCity,
    required final String dropoffCity,
    required final int itemCount,
    required final int deliveryFeeFcfa,
    final DateTime? acceptedAt,
    final DateTime? pickedUpAt,
    final DateTime? deliveredAt,
    final int? clientStars,
    final int? supplierStars,
  }) = _$CourierHistoryEntryImpl;

  @override
  String get deliveryId;

  /// Référence courte, citable au support sans lire 36 caractères.
  @override
  String get reference;
  @override
  DeliveryStatus get status;
  @override
  String get pickupCity;
  @override
  String get dropoffCity;
  @override
  int get itemCount;
  @override
  int get deliveryFeeFcfa;
  @override
  DateTime? get acceptedAt;
  @override
  DateTime? get pickedUpAt;
  @override
  DateTime? get deliveredAt;

  /// Notes reçues pour cette course, côté par côté — `null` quand ce côté
  /// n'a pas noté.
  @override
  int? get clientStars;
  @override
  int? get supplierStars;

  /// Create a copy of CourierHistoryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierHistoryEntryImplCopyWith<_$CourierHistoryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CourierStats {
  int get deliveredCount => throw _privateConstructorUsedError;
  int get deliveredFeesFcfa => throw _privateConstructorUsedError;
  int get monthDeliveredCount => throw _privateConstructorUsedError;
  int get monthFeesFcfa => throw _privateConstructorUsedError;
  int get cancelledCount => throw _privateConstructorUsedError;
  double get ratingAverage => throw _privateConstructorUsedError;
  int get ratingCount => throw _privateConstructorUsedError;

  /// Create a copy of CourierStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierStatsCopyWith<CourierStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierStatsCopyWith<$Res> {
  factory $CourierStatsCopyWith(
    CourierStats value,
    $Res Function(CourierStats) then,
  ) = _$CourierStatsCopyWithImpl<$Res, CourierStats>;
  @useResult
  $Res call({
    int deliveredCount,
    int deliveredFeesFcfa,
    int monthDeliveredCount,
    int monthFeesFcfa,
    int cancelledCount,
    double ratingAverage,
    int ratingCount,
  });
}

/// @nodoc
class _$CourierStatsCopyWithImpl<$Res, $Val extends CourierStats>
    implements $CourierStatsCopyWith<$Res> {
  _$CourierStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deliveredCount = null,
    Object? deliveredFeesFcfa = null,
    Object? monthDeliveredCount = null,
    Object? monthFeesFcfa = null,
    Object? cancelledCount = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
  }) {
    return _then(
      _value.copyWith(
            deliveredCount: null == deliveredCount
                ? _value.deliveredCount
                : deliveredCount // ignore: cast_nullable_to_non_nullable
                      as int,
            deliveredFeesFcfa: null == deliveredFeesFcfa
                ? _value.deliveredFeesFcfa
                : deliveredFeesFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            monthDeliveredCount: null == monthDeliveredCount
                ? _value.monthDeliveredCount
                : monthDeliveredCount // ignore: cast_nullable_to_non_nullable
                      as int,
            monthFeesFcfa: null == monthFeesFcfa
                ? _value.monthFeesFcfa
                : monthFeesFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            cancelledCount: null == cancelledCount
                ? _value.cancelledCount
                : cancelledCount // ignore: cast_nullable_to_non_nullable
                      as int,
            ratingAverage: null == ratingAverage
                ? _value.ratingAverage
                : ratingAverage // ignore: cast_nullable_to_non_nullable
                      as double,
            ratingCount: null == ratingCount
                ? _value.ratingCount
                : ratingCount // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierStatsImplCopyWith<$Res>
    implements $CourierStatsCopyWith<$Res> {
  factory _$$CourierStatsImplCopyWith(
    _$CourierStatsImpl value,
    $Res Function(_$CourierStatsImpl) then,
  ) = __$$CourierStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int deliveredCount,
    int deliveredFeesFcfa,
    int monthDeliveredCount,
    int monthFeesFcfa,
    int cancelledCount,
    double ratingAverage,
    int ratingCount,
  });
}

/// @nodoc
class __$$CourierStatsImplCopyWithImpl<$Res>
    extends _$CourierStatsCopyWithImpl<$Res, _$CourierStatsImpl>
    implements _$$CourierStatsImplCopyWith<$Res> {
  __$$CourierStatsImplCopyWithImpl(
    _$CourierStatsImpl _value,
    $Res Function(_$CourierStatsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? deliveredCount = null,
    Object? deliveredFeesFcfa = null,
    Object? monthDeliveredCount = null,
    Object? monthFeesFcfa = null,
    Object? cancelledCount = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
  }) {
    return _then(
      _$CourierStatsImpl(
        deliveredCount: null == deliveredCount
            ? _value.deliveredCount
            : deliveredCount // ignore: cast_nullable_to_non_nullable
                  as int,
        deliveredFeesFcfa: null == deliveredFeesFcfa
            ? _value.deliveredFeesFcfa
            : deliveredFeesFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        monthDeliveredCount: null == monthDeliveredCount
            ? _value.monthDeliveredCount
            : monthDeliveredCount // ignore: cast_nullable_to_non_nullable
                  as int,
        monthFeesFcfa: null == monthFeesFcfa
            ? _value.monthFeesFcfa
            : monthFeesFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        cancelledCount: null == cancelledCount
            ? _value.cancelledCount
            : cancelledCount // ignore: cast_nullable_to_non_nullable
                  as int,
        ratingAverage: null == ratingAverage
            ? _value.ratingAverage
            : ratingAverage // ignore: cast_nullable_to_non_nullable
                  as double,
        ratingCount: null == ratingCount
            ? _value.ratingCount
            : ratingCount // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$CourierStatsImpl implements _CourierStats {
  const _$CourierStatsImpl({
    required this.deliveredCount,
    required this.deliveredFeesFcfa,
    required this.monthDeliveredCount,
    required this.monthFeesFcfa,
    required this.cancelledCount,
    required this.ratingAverage,
    required this.ratingCount,
  });

  @override
  final int deliveredCount;
  @override
  final int deliveredFeesFcfa;
  @override
  final int monthDeliveredCount;
  @override
  final int monthFeesFcfa;
  @override
  final int cancelledCount;
  @override
  final double ratingAverage;
  @override
  final int ratingCount;

  @override
  String toString() {
    return 'CourierStats(deliveredCount: $deliveredCount, deliveredFeesFcfa: $deliveredFeesFcfa, monthDeliveredCount: $monthDeliveredCount, monthFeesFcfa: $monthFeesFcfa, cancelledCount: $cancelledCount, ratingAverage: $ratingAverage, ratingCount: $ratingCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierStatsImpl &&
            (identical(other.deliveredCount, deliveredCount) ||
                other.deliveredCount == deliveredCount) &&
            (identical(other.deliveredFeesFcfa, deliveredFeesFcfa) ||
                other.deliveredFeesFcfa == deliveredFeesFcfa) &&
            (identical(other.monthDeliveredCount, monthDeliveredCount) ||
                other.monthDeliveredCount == monthDeliveredCount) &&
            (identical(other.monthFeesFcfa, monthFeesFcfa) ||
                other.monthFeesFcfa == monthFeesFcfa) &&
            (identical(other.cancelledCount, cancelledCount) ||
                other.cancelledCount == cancelledCount) &&
            (identical(other.ratingAverage, ratingAverage) ||
                other.ratingAverage == ratingAverage) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    deliveredCount,
    deliveredFeesFcfa,
    monthDeliveredCount,
    monthFeesFcfa,
    cancelledCount,
    ratingAverage,
    ratingCount,
  );

  /// Create a copy of CourierStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierStatsImplCopyWith<_$CourierStatsImpl> get copyWith =>
      __$$CourierStatsImplCopyWithImpl<_$CourierStatsImpl>(this, _$identity);
}

abstract class _CourierStats implements CourierStats {
  const factory _CourierStats({
    required final int deliveredCount,
    required final int deliveredFeesFcfa,
    required final int monthDeliveredCount,
    required final int monthFeesFcfa,
    required final int cancelledCount,
    required final double ratingAverage,
    required final int ratingCount,
  }) = _$CourierStatsImpl;

  @override
  int get deliveredCount;
  @override
  int get deliveredFeesFcfa;
  @override
  int get monthDeliveredCount;
  @override
  int get monthFeesFcfa;
  @override
  int get cancelledCount;
  @override
  double get ratingAverage;
  @override
  int get ratingCount;

  /// Create a copy of CourierStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierStatsImplCopyWith<_$CourierStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CourierRating {
  int get stars => throw _privateConstructorUsedError;
  CourierRaterRole get raterRole => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  String get deliveryId => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;

  /// Create a copy of CourierRating
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierRatingCopyWith<CourierRating> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierRatingCopyWith<$Res> {
  factory $CourierRatingCopyWith(
    CourierRating value,
    $Res Function(CourierRating) then,
  ) = _$CourierRatingCopyWithImpl<$Res, CourierRating>;
  @useResult
  $Res call({
    int stars,
    CourierRaterRole raterRole,
    DateTime createdAt,
    String deliveryId,
    String? comment,
  });
}

/// @nodoc
class _$CourierRatingCopyWithImpl<$Res, $Val extends CourierRating>
    implements $CourierRatingCopyWith<$Res> {
  _$CourierRatingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierRating
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stars = null,
    Object? raterRole = null,
    Object? createdAt = null,
    Object? deliveryId = null,
    Object? comment = freezed,
  }) {
    return _then(
      _value.copyWith(
            stars: null == stars
                ? _value.stars
                : stars // ignore: cast_nullable_to_non_nullable
                      as int,
            raterRole: null == raterRole
                ? _value.raterRole
                : raterRole // ignore: cast_nullable_to_non_nullable
                      as CourierRaterRole,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            deliveryId: null == deliveryId
                ? _value.deliveryId
                : deliveryId // ignore: cast_nullable_to_non_nullable
                      as String,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierRatingImplCopyWith<$Res>
    implements $CourierRatingCopyWith<$Res> {
  factory _$$CourierRatingImplCopyWith(
    _$CourierRatingImpl value,
    $Res Function(_$CourierRatingImpl) then,
  ) = __$$CourierRatingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int stars,
    CourierRaterRole raterRole,
    DateTime createdAt,
    String deliveryId,
    String? comment,
  });
}

/// @nodoc
class __$$CourierRatingImplCopyWithImpl<$Res>
    extends _$CourierRatingCopyWithImpl<$Res, _$CourierRatingImpl>
    implements _$$CourierRatingImplCopyWith<$Res> {
  __$$CourierRatingImplCopyWithImpl(
    _$CourierRatingImpl _value,
    $Res Function(_$CourierRatingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierRating
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? stars = null,
    Object? raterRole = null,
    Object? createdAt = null,
    Object? deliveryId = null,
    Object? comment = freezed,
  }) {
    return _then(
      _$CourierRatingImpl(
        stars: null == stars
            ? _value.stars
            : stars // ignore: cast_nullable_to_non_nullable
                  as int,
        raterRole: null == raterRole
            ? _value.raterRole
            : raterRole // ignore: cast_nullable_to_non_nullable
                  as CourierRaterRole,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        deliveryId: null == deliveryId
            ? _value.deliveryId
            : deliveryId // ignore: cast_nullable_to_non_nullable
                  as String,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$CourierRatingImpl implements _CourierRating {
  const _$CourierRatingImpl({
    required this.stars,
    required this.raterRole,
    required this.createdAt,
    required this.deliveryId,
    this.comment,
  });

  @override
  final int stars;
  @override
  final CourierRaterRole raterRole;
  @override
  final DateTime createdAt;
  @override
  final String deliveryId;
  @override
  final String? comment;

  @override
  String toString() {
    return 'CourierRating(stars: $stars, raterRole: $raterRole, createdAt: $createdAt, deliveryId: $deliveryId, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierRatingImpl &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.raterRole, raterRole) ||
                other.raterRole == raterRole) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.deliveryId, deliveryId) ||
                other.deliveryId == deliveryId) &&
            (identical(other.comment, comment) || other.comment == comment));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    stars,
    raterRole,
    createdAt,
    deliveryId,
    comment,
  );

  /// Create a copy of CourierRating
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierRatingImplCopyWith<_$CourierRatingImpl> get copyWith =>
      __$$CourierRatingImplCopyWithImpl<_$CourierRatingImpl>(this, _$identity);
}

abstract class _CourierRating implements CourierRating {
  const factory _CourierRating({
    required final int stars,
    required final CourierRaterRole raterRole,
    required final DateTime createdAt,
    required final String deliveryId,
    final String? comment,
  }) = _$CourierRatingImpl;

  @override
  int get stars;
  @override
  CourierRaterRole get raterRole;
  @override
  DateTime get createdAt;
  @override
  String get deliveryId;
  @override
  String? get comment;

  /// Create a copy of CourierRating
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierRatingImplCopyWith<_$CourierRatingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$MyDeliveryRating {
  int get stars => throw _privateConstructorUsedError;
  String? get comment => throw _privateConstructorUsedError;

  /// Create a copy of MyDeliveryRating
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MyDeliveryRatingCopyWith<MyDeliveryRating> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MyDeliveryRatingCopyWith<$Res> {
  factory $MyDeliveryRatingCopyWith(
    MyDeliveryRating value,
    $Res Function(MyDeliveryRating) then,
  ) = _$MyDeliveryRatingCopyWithImpl<$Res, MyDeliveryRating>;
  @useResult
  $Res call({int stars, String? comment});
}

/// @nodoc
class _$MyDeliveryRatingCopyWithImpl<$Res, $Val extends MyDeliveryRating>
    implements $MyDeliveryRatingCopyWith<$Res> {
  _$MyDeliveryRatingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MyDeliveryRating
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? stars = null, Object? comment = freezed}) {
    return _then(
      _value.copyWith(
            stars: null == stars
                ? _value.stars
                : stars // ignore: cast_nullable_to_non_nullable
                      as int,
            comment: freezed == comment
                ? _value.comment
                : comment // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$MyDeliveryRatingImplCopyWith<$Res>
    implements $MyDeliveryRatingCopyWith<$Res> {
  factory _$$MyDeliveryRatingImplCopyWith(
    _$MyDeliveryRatingImpl value,
    $Res Function(_$MyDeliveryRatingImpl) then,
  ) = __$$MyDeliveryRatingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int stars, String? comment});
}

/// @nodoc
class __$$MyDeliveryRatingImplCopyWithImpl<$Res>
    extends _$MyDeliveryRatingCopyWithImpl<$Res, _$MyDeliveryRatingImpl>
    implements _$$MyDeliveryRatingImplCopyWith<$Res> {
  __$$MyDeliveryRatingImplCopyWithImpl(
    _$MyDeliveryRatingImpl _value,
    $Res Function(_$MyDeliveryRatingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of MyDeliveryRating
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? stars = null, Object? comment = freezed}) {
    return _then(
      _$MyDeliveryRatingImpl(
        stars: null == stars
            ? _value.stars
            : stars // ignore: cast_nullable_to_non_nullable
                  as int,
        comment: freezed == comment
            ? _value.comment
            : comment // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$MyDeliveryRatingImpl implements _MyDeliveryRating {
  const _$MyDeliveryRatingImpl({required this.stars, this.comment});

  @override
  final int stars;
  @override
  final String? comment;

  @override
  String toString() {
    return 'MyDeliveryRating(stars: $stars, comment: $comment)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MyDeliveryRatingImpl &&
            (identical(other.stars, stars) || other.stars == stars) &&
            (identical(other.comment, comment) || other.comment == comment));
  }

  @override
  int get hashCode => Object.hash(runtimeType, stars, comment);

  /// Create a copy of MyDeliveryRating
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MyDeliveryRatingImplCopyWith<_$MyDeliveryRatingImpl> get copyWith =>
      __$$MyDeliveryRatingImplCopyWithImpl<_$MyDeliveryRatingImpl>(
        this,
        _$identity,
      );
}

abstract class _MyDeliveryRating implements MyDeliveryRating {
  const factory _MyDeliveryRating({
    required final int stars,
    final String? comment,
  }) = _$MyDeliveryRatingImpl;

  @override
  int get stars;
  @override
  String? get comment;

  /// Create a copy of MyDeliveryRating
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MyDeliveryRatingImplCopyWith<_$MyDeliveryRatingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
