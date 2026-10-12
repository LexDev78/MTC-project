// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'supplier_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

SupplierProfile _$SupplierProfileFromJson(Map<String, dynamic> json) {
  return _SupplierProfile.fromJson(json);
}

/// @nodoc
mixin _$SupplierProfile {
  String get id => throw _privateConstructorUsedError;
  String get businessName => throw _privateConstructorUsedError;
  SupplierType get supplierType => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  double get ratingAverage => throw _privateConstructorUsedError;
  int get ratingCount => throw _privateConstructorUsedError;
  int get productCount => throw _privateConstructorUsedError;
  VerificationStatus? get verificationStatus =>
      throw _privateConstructorUsedError; // Null for `SupplierType.principal` (MTC itself has no legal form to
  // register) — only ever set for `SupplierType.tiers`.
  SupplierLegalType? get legalType =>
      throw _privateConstructorUsedError; // Extended storefront fields (Lot 11) — edited from
  // `SupplierAccountController.updateStorefront`, shown on the public
  // `SupplierProfileScreen`.
  String? get description => throw _privateConstructorUsedError;
  String? get bannerUrl => throw _privateConstructorUsedError;
  String? get fullAddress => throw _privateConstructorUsedError;

  /// Derived from `city` via `MalianCity` (same lookup
  /// `ManageAddressesScreen` uses for a client address) rather than typed
  /// in by hand — no map picker in this app, and every seeded city
  /// already has known coordinates. Usable with `GeoDistance`.
  double? get addressLatitude => throw _privateConstructorUsedError;
  double? get addressLongitude => throw _privateConstructorUsedError;
  List<String> get publicPhoneNumbers => throw _privateConstructorUsedError;
  List<String> get deliveryZones => throw _privateConstructorUsedError;
  String? get openingHoursLabel => throw _privateConstructorUsedError;
  bool get isOpen => throw _privateConstructorUsedError;

  /// Serializes this SupplierProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SupplierProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SupplierProfileCopyWith<SupplierProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SupplierProfileCopyWith<$Res> {
  factory $SupplierProfileCopyWith(
    SupplierProfile value,
    $Res Function(SupplierProfile) then,
  ) = _$SupplierProfileCopyWithImpl<$Res, SupplierProfile>;
  @useResult
  $Res call({
    String id,
    String businessName,
    SupplierType supplierType,
    String city,
    double ratingAverage,
    int ratingCount,
    int productCount,
    VerificationStatus? verificationStatus,
    SupplierLegalType? legalType,
    String? description,
    String? bannerUrl,
    String? fullAddress,
    double? addressLatitude,
    double? addressLongitude,
    List<String> publicPhoneNumbers,
    List<String> deliveryZones,
    String? openingHoursLabel,
    bool isOpen,
  });
}

/// @nodoc
class _$SupplierProfileCopyWithImpl<$Res, $Val extends SupplierProfile>
    implements $SupplierProfileCopyWith<$Res> {
  _$SupplierProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SupplierProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessName = null,
    Object? supplierType = null,
    Object? city = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
    Object? productCount = null,
    Object? verificationStatus = freezed,
    Object? legalType = freezed,
    Object? description = freezed,
    Object? bannerUrl = freezed,
    Object? fullAddress = freezed,
    Object? addressLatitude = freezed,
    Object? addressLongitude = freezed,
    Object? publicPhoneNumbers = null,
    Object? deliveryZones = null,
    Object? openingHoursLabel = freezed,
    Object? isOpen = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            businessName: null == businessName
                ? _value.businessName
                : businessName // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierType: null == supplierType
                ? _value.supplierType
                : supplierType // ignore: cast_nullable_to_non_nullable
                      as SupplierType,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            ratingAverage: null == ratingAverage
                ? _value.ratingAverage
                : ratingAverage // ignore: cast_nullable_to_non_nullable
                      as double,
            ratingCount: null == ratingCount
                ? _value.ratingCount
                : ratingCount // ignore: cast_nullable_to_non_nullable
                      as int,
            productCount: null == productCount
                ? _value.productCount
                : productCount // ignore: cast_nullable_to_non_nullable
                      as int,
            verificationStatus: freezed == verificationStatus
                ? _value.verificationStatus
                : verificationStatus // ignore: cast_nullable_to_non_nullable
                      as VerificationStatus?,
            legalType: freezed == legalType
                ? _value.legalType
                : legalType // ignore: cast_nullable_to_non_nullable
                      as SupplierLegalType?,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            bannerUrl: freezed == bannerUrl
                ? _value.bannerUrl
                : bannerUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            fullAddress: freezed == fullAddress
                ? _value.fullAddress
                : fullAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
            addressLatitude: freezed == addressLatitude
                ? _value.addressLatitude
                : addressLatitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            addressLongitude: freezed == addressLongitude
                ? _value.addressLongitude
                : addressLongitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            publicPhoneNumbers: null == publicPhoneNumbers
                ? _value.publicPhoneNumbers
                : publicPhoneNumbers // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            deliveryZones: null == deliveryZones
                ? _value.deliveryZones
                : deliveryZones // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            openingHoursLabel: freezed == openingHoursLabel
                ? _value.openingHoursLabel
                : openingHoursLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            isOpen: null == isOpen
                ? _value.isOpen
                : isOpen // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SupplierProfileImplCopyWith<$Res>
    implements $SupplierProfileCopyWith<$Res> {
  factory _$$SupplierProfileImplCopyWith(
    _$SupplierProfileImpl value,
    $Res Function(_$SupplierProfileImpl) then,
  ) = __$$SupplierProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String businessName,
    SupplierType supplierType,
    String city,
    double ratingAverage,
    int ratingCount,
    int productCount,
    VerificationStatus? verificationStatus,
    SupplierLegalType? legalType,
    String? description,
    String? bannerUrl,
    String? fullAddress,
    double? addressLatitude,
    double? addressLongitude,
    List<String> publicPhoneNumbers,
    List<String> deliveryZones,
    String? openingHoursLabel,
    bool isOpen,
  });
}

/// @nodoc
class __$$SupplierProfileImplCopyWithImpl<$Res>
    extends _$SupplierProfileCopyWithImpl<$Res, _$SupplierProfileImpl>
    implements _$$SupplierProfileImplCopyWith<$Res> {
  __$$SupplierProfileImplCopyWithImpl(
    _$SupplierProfileImpl _value,
    $Res Function(_$SupplierProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SupplierProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? businessName = null,
    Object? supplierType = null,
    Object? city = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
    Object? productCount = null,
    Object? verificationStatus = freezed,
    Object? legalType = freezed,
    Object? description = freezed,
    Object? bannerUrl = freezed,
    Object? fullAddress = freezed,
    Object? addressLatitude = freezed,
    Object? addressLongitude = freezed,
    Object? publicPhoneNumbers = null,
    Object? deliveryZones = null,
    Object? openingHoursLabel = freezed,
    Object? isOpen = null,
  }) {
    return _then(
      _$SupplierProfileImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        businessName: null == businessName
            ? _value.businessName
            : businessName // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierType: null == supplierType
            ? _value.supplierType
            : supplierType // ignore: cast_nullable_to_non_nullable
                  as SupplierType,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        ratingAverage: null == ratingAverage
            ? _value.ratingAverage
            : ratingAverage // ignore: cast_nullable_to_non_nullable
                  as double,
        ratingCount: null == ratingCount
            ? _value.ratingCount
            : ratingCount // ignore: cast_nullable_to_non_nullable
                  as int,
        productCount: null == productCount
            ? _value.productCount
            : productCount // ignore: cast_nullable_to_non_nullable
                  as int,
        verificationStatus: freezed == verificationStatus
            ? _value.verificationStatus
            : verificationStatus // ignore: cast_nullable_to_non_nullable
                  as VerificationStatus?,
        legalType: freezed == legalType
            ? _value.legalType
            : legalType // ignore: cast_nullable_to_non_nullable
                  as SupplierLegalType?,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        bannerUrl: freezed == bannerUrl
            ? _value.bannerUrl
            : bannerUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        fullAddress: freezed == fullAddress
            ? _value.fullAddress
            : fullAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
        addressLatitude: freezed == addressLatitude
            ? _value.addressLatitude
            : addressLatitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        addressLongitude: freezed == addressLongitude
            ? _value.addressLongitude
            : addressLongitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        publicPhoneNumbers: null == publicPhoneNumbers
            ? _value._publicPhoneNumbers
            : publicPhoneNumbers // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        deliveryZones: null == deliveryZones
            ? _value._deliveryZones
            : deliveryZones // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        openingHoursLabel: freezed == openingHoursLabel
            ? _value.openingHoursLabel
            : openingHoursLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        isOpen: null == isOpen
            ? _value.isOpen
            : isOpen // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SupplierProfileImpl implements _SupplierProfile {
  const _$SupplierProfileImpl({
    required this.id,
    required this.businessName,
    required this.supplierType,
    required this.city,
    required this.ratingAverage,
    required this.ratingCount,
    required this.productCount,
    this.verificationStatus,
    this.legalType,
    this.description,
    this.bannerUrl,
    this.fullAddress,
    this.addressLatitude,
    this.addressLongitude,
    final List<String> publicPhoneNumbers = const <String>[],
    final List<String> deliveryZones = const <String>[],
    this.openingHoursLabel,
    this.isOpen = true,
  }) : _publicPhoneNumbers = publicPhoneNumbers,
       _deliveryZones = deliveryZones;

  factory _$SupplierProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$SupplierProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String businessName;
  @override
  final SupplierType supplierType;
  @override
  final String city;
  @override
  final double ratingAverage;
  @override
  final int ratingCount;
  @override
  final int productCount;
  @override
  final VerificationStatus? verificationStatus;
  // Null for `SupplierType.principal` (MTC itself has no legal form to
  // register) — only ever set for `SupplierType.tiers`.
  @override
  final SupplierLegalType? legalType;
  // Extended storefront fields (Lot 11) — edited from
  // `SupplierAccountController.updateStorefront`, shown on the public
  // `SupplierProfileScreen`.
  @override
  final String? description;
  @override
  final String? bannerUrl;
  @override
  final String? fullAddress;

  /// Derived from `city` via `MalianCity` (same lookup
  /// `ManageAddressesScreen` uses for a client address) rather than typed
  /// in by hand — no map picker in this app, and every seeded city
  /// already has known coordinates. Usable with `GeoDistance`.
  @override
  final double? addressLatitude;
  @override
  final double? addressLongitude;
  final List<String> _publicPhoneNumbers;
  @override
  @JsonKey()
  List<String> get publicPhoneNumbers {
    if (_publicPhoneNumbers is EqualUnmodifiableListView)
      return _publicPhoneNumbers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_publicPhoneNumbers);
  }

  final List<String> _deliveryZones;
  @override
  @JsonKey()
  List<String> get deliveryZones {
    if (_deliveryZones is EqualUnmodifiableListView) return _deliveryZones;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_deliveryZones);
  }

  @override
  final String? openingHoursLabel;
  @override
  @JsonKey()
  final bool isOpen;

  @override
  String toString() {
    return 'SupplierProfile(id: $id, businessName: $businessName, supplierType: $supplierType, city: $city, ratingAverage: $ratingAverage, ratingCount: $ratingCount, productCount: $productCount, verificationStatus: $verificationStatus, legalType: $legalType, description: $description, bannerUrl: $bannerUrl, fullAddress: $fullAddress, addressLatitude: $addressLatitude, addressLongitude: $addressLongitude, publicPhoneNumbers: $publicPhoneNumbers, deliveryZones: $deliveryZones, openingHoursLabel: $openingHoursLabel, isOpen: $isOpen)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.businessName, businessName) ||
                other.businessName == businessName) &&
            (identical(other.supplierType, supplierType) ||
                other.supplierType == supplierType) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.ratingAverage, ratingAverage) ||
                other.ratingAverage == ratingAverage) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.productCount, productCount) ||
                other.productCount == productCount) &&
            (identical(other.verificationStatus, verificationStatus) ||
                other.verificationStatus == verificationStatus) &&
            (identical(other.legalType, legalType) ||
                other.legalType == legalType) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.bannerUrl, bannerUrl) ||
                other.bannerUrl == bannerUrl) &&
            (identical(other.fullAddress, fullAddress) ||
                other.fullAddress == fullAddress) &&
            (identical(other.addressLatitude, addressLatitude) ||
                other.addressLatitude == addressLatitude) &&
            (identical(other.addressLongitude, addressLongitude) ||
                other.addressLongitude == addressLongitude) &&
            const DeepCollectionEquality().equals(
              other._publicPhoneNumbers,
              _publicPhoneNumbers,
            ) &&
            const DeepCollectionEquality().equals(
              other._deliveryZones,
              _deliveryZones,
            ) &&
            (identical(other.openingHoursLabel, openingHoursLabel) ||
                other.openingHoursLabel == openingHoursLabel) &&
            (identical(other.isOpen, isOpen) || other.isOpen == isOpen));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    businessName,
    supplierType,
    city,
    ratingAverage,
    ratingCount,
    productCount,
    verificationStatus,
    legalType,
    description,
    bannerUrl,
    fullAddress,
    addressLatitude,
    addressLongitude,
    const DeepCollectionEquality().hash(_publicPhoneNumbers),
    const DeepCollectionEquality().hash(_deliveryZones),
    openingHoursLabel,
    isOpen,
  );

  /// Create a copy of SupplierProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierProfileImplCopyWith<_$SupplierProfileImpl> get copyWith =>
      __$$SupplierProfileImplCopyWithImpl<_$SupplierProfileImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SupplierProfileImplToJson(this);
  }
}

abstract class _SupplierProfile implements SupplierProfile {
  const factory _SupplierProfile({
    required final String id,
    required final String businessName,
    required final SupplierType supplierType,
    required final String city,
    required final double ratingAverage,
    required final int ratingCount,
    required final int productCount,
    final VerificationStatus? verificationStatus,
    final SupplierLegalType? legalType,
    final String? description,
    final String? bannerUrl,
    final String? fullAddress,
    final double? addressLatitude,
    final double? addressLongitude,
    final List<String> publicPhoneNumbers,
    final List<String> deliveryZones,
    final String? openingHoursLabel,
    final bool isOpen,
  }) = _$SupplierProfileImpl;

  factory _SupplierProfile.fromJson(Map<String, dynamic> json) =
      _$SupplierProfileImpl.fromJson;

  @override
  String get id;
  @override
  String get businessName;
  @override
  SupplierType get supplierType;
  @override
  String get city;
  @override
  double get ratingAverage;
  @override
  int get ratingCount;
  @override
  int get productCount;
  @override
  VerificationStatus? get verificationStatus; // Null for `SupplierType.principal` (MTC itself has no legal form to
  // register) — only ever set for `SupplierType.tiers`.
  @override
  SupplierLegalType? get legalType; // Extended storefront fields (Lot 11) — edited from
  // `SupplierAccountController.updateStorefront`, shown on the public
  // `SupplierProfileScreen`.
  @override
  String? get description;
  @override
  String? get bannerUrl;
  @override
  String? get fullAddress;

  /// Derived from `city` via `MalianCity` (same lookup
  /// `ManageAddressesScreen` uses for a client address) rather than typed
  /// in by hand — no map picker in this app, and every seeded city
  /// already has known coordinates. Usable with `GeoDistance`.
  @override
  double? get addressLatitude;
  @override
  double? get addressLongitude;
  @override
  List<String> get publicPhoneNumbers;
  @override
  List<String> get deliveryZones;
  @override
  String? get openingHoursLabel;
  @override
  bool get isOpen;

  /// Create a copy of SupplierProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierProfileImplCopyWith<_$SupplierProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
