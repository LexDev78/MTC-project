// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_user.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AppUser {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get usernameOrPhone => throw _privateConstructorUsedError;
  String get phoneNumber => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )
    client,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )
    supplierTiers,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )
    courier,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )
    supplierPrincipal,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ClientUser value) client,
    required TResult Function(SupplierTiersUser value) supplierTiers,
    required TResult Function(CourierUser value) courier,
    required TResult Function(SupplierPrincipalUser value) supplierPrincipal,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ClientUser value)? client,
    TResult? Function(SupplierTiersUser value)? supplierTiers,
    TResult? Function(CourierUser value)? courier,
    TResult? Function(SupplierPrincipalUser value)? supplierPrincipal,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ClientUser value)? client,
    TResult Function(SupplierTiersUser value)? supplierTiers,
    TResult Function(CourierUser value)? courier,
    TResult Function(SupplierPrincipalUser value)? supplierPrincipal,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppUserCopyWith<AppUser> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppUserCopyWith<$Res> {
  factory $AppUserCopyWith(AppUser value, $Res Function(AppUser) then) =
      _$AppUserCopyWithImpl<$Res, AppUser>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String usernameOrPhone,
    String phoneNumber,
    DateTime createdAt,
  });
}

/// @nodoc
class _$AppUserCopyWithImpl<$Res, $Val extends AppUser>
    implements $AppUserCopyWith<$Res> {
  _$AppUserCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? usernameOrPhone = null,
    Object? phoneNumber = null,
    Object? createdAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            usernameOrPhone: null == usernameOrPhone
                ? _value.usernameOrPhone
                : usernameOrPhone // ignore: cast_nullable_to_non_nullable
                      as String,
            phoneNumber: null == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ClientUserImplCopyWith<$Res>
    implements $AppUserCopyWith<$Res> {
  factory _$$ClientUserImplCopyWith(
    _$ClientUserImpl value,
    $Res Function(_$ClientUserImpl) then,
  ) = __$$ClientUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String usernameOrPhone,
    String phoneNumber,
    DateTime createdAt,
    String? defaultAddressId,
  });
}

/// @nodoc
class __$$ClientUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$ClientUserImpl>
    implements _$$ClientUserImplCopyWith<$Res> {
  __$$ClientUserImplCopyWithImpl(
    _$ClientUserImpl _value,
    $Res Function(_$ClientUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? usernameOrPhone = null,
    Object? phoneNumber = null,
    Object? createdAt = null,
    Object? defaultAddressId = freezed,
  }) {
    return _then(
      _$ClientUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        usernameOrPhone: null == usernameOrPhone
            ? _value.usernameOrPhone
            : usernameOrPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        defaultAddressId: freezed == defaultAddressId
            ? _value.defaultAddressId
            : defaultAddressId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$ClientUserImpl implements ClientUser {
  const _$ClientUserImpl({
    required this.id,
    required this.displayName,
    required this.usernameOrPhone,
    required this.phoneNumber,
    required this.createdAt,
    this.defaultAddressId,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String usernameOrPhone;
  @override
  final String phoneNumber;
  @override
  final DateTime createdAt;
  @override
  final String? defaultAddressId;

  @override
  String toString() {
    return 'AppUser.client(id: $id, displayName: $displayName, usernameOrPhone: $usernameOrPhone, phoneNumber: $phoneNumber, createdAt: $createdAt, defaultAddressId: $defaultAddressId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ClientUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.usernameOrPhone, usernameOrPhone) ||
                other.usernameOrPhone == usernameOrPhone) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.defaultAddressId, defaultAddressId) ||
                other.defaultAddressId == defaultAddressId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    usernameOrPhone,
    phoneNumber,
    createdAt,
    defaultAddressId,
  );

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ClientUserImplCopyWith<_$ClientUserImpl> get copyWith =>
      __$$ClientUserImplCopyWithImpl<_$ClientUserImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )
    client,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )
    supplierTiers,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )
    courier,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )
    supplierPrincipal,
  }) {
    return client(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      defaultAddressId,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
  }) {
    return client?.call(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      defaultAddressId,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
    required TResult orElse(),
  }) {
    if (client != null) {
      return client(
        id,
        displayName,
        usernameOrPhone,
        phoneNumber,
        createdAt,
        defaultAddressId,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ClientUser value) client,
    required TResult Function(SupplierTiersUser value) supplierTiers,
    required TResult Function(CourierUser value) courier,
    required TResult Function(SupplierPrincipalUser value) supplierPrincipal,
  }) {
    return client(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ClientUser value)? client,
    TResult? Function(SupplierTiersUser value)? supplierTiers,
    TResult? Function(CourierUser value)? courier,
    TResult? Function(SupplierPrincipalUser value)? supplierPrincipal,
  }) {
    return client?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ClientUser value)? client,
    TResult Function(SupplierTiersUser value)? supplierTiers,
    TResult Function(CourierUser value)? courier,
    TResult Function(SupplierPrincipalUser value)? supplierPrincipal,
    required TResult orElse(),
  }) {
    if (client != null) {
      return client(this);
    }
    return orElse();
  }
}

abstract class ClientUser implements AppUser {
  const factory ClientUser({
    required final String id,
    required final String displayName,
    required final String usernameOrPhone,
    required final String phoneNumber,
    required final DateTime createdAt,
    final String? defaultAddressId,
  }) = _$ClientUserImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get usernameOrPhone;
  @override
  String get phoneNumber;
  @override
  DateTime get createdAt;
  String? get defaultAddressId;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ClientUserImplCopyWith<_$ClientUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SupplierTiersUserImplCopyWith<$Res>
    implements $AppUserCopyWith<$Res> {
  factory _$$SupplierTiersUserImplCopyWith(
    _$SupplierTiersUserImpl value,
    $Res Function(_$SupplierTiersUserImpl) then,
  ) = __$$SupplierTiersUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String usernameOrPhone,
    String phoneNumber,
    DateTime createdAt,
    String businessName,
    VerificationStatus verificationStatus,
    String city,
    double ratingAverage,
    int ratingCount,
    SupplierLegalType legalType,
    String? operatesSupplierId,
    List<String> permissions,
    bool mustChangePassword,
  });
}

/// @nodoc
class __$$SupplierTiersUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$SupplierTiersUserImpl>
    implements _$$SupplierTiersUserImplCopyWith<$Res> {
  __$$SupplierTiersUserImplCopyWithImpl(
    _$SupplierTiersUserImpl _value,
    $Res Function(_$SupplierTiersUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? usernameOrPhone = null,
    Object? phoneNumber = null,
    Object? createdAt = null,
    Object? businessName = null,
    Object? verificationStatus = null,
    Object? city = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
    Object? legalType = null,
    Object? operatesSupplierId = freezed,
    Object? permissions = null,
    Object? mustChangePassword = null,
  }) {
    return _then(
      _$SupplierTiersUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        usernameOrPhone: null == usernameOrPhone
            ? _value.usernameOrPhone
            : usernameOrPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        businessName: null == businessName
            ? _value.businessName
            : businessName // ignore: cast_nullable_to_non_nullable
                  as String,
        verificationStatus: null == verificationStatus
            ? _value.verificationStatus
            : verificationStatus // ignore: cast_nullable_to_non_nullable
                  as VerificationStatus,
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
        legalType: null == legalType
            ? _value.legalType
            : legalType // ignore: cast_nullable_to_non_nullable
                  as SupplierLegalType,
        operatesSupplierId: freezed == operatesSupplierId
            ? _value.operatesSupplierId
            : operatesSupplierId // ignore: cast_nullable_to_non_nullable
                  as String?,
        permissions: null == permissions
            ? _value._permissions
            : permissions // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        mustChangePassword: null == mustChangePassword
            ? _value.mustChangePassword
            : mustChangePassword // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$SupplierTiersUserImpl implements SupplierTiersUser {
  const _$SupplierTiersUserImpl({
    required this.id,
    required this.displayName,
    required this.usernameOrPhone,
    required this.phoneNumber,
    required this.createdAt,
    required this.businessName,
    required this.verificationStatus,
    required this.city,
    required this.ratingAverage,
    required this.ratingCount,
    required this.legalType,
    this.operatesSupplierId,
    final List<String> permissions = const [],
    this.mustChangePassword = false,
  }) : _permissions = permissions;

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String usernameOrPhone;
  @override
  final String phoneNumber;
  @override
  final DateTime createdAt;
  @override
  final String businessName;
  @override
  final VerificationStatus verificationStatus;
  @override
  final String city;
  @override
  final double ratingAverage;
  @override
  final int ratingCount;
  @override
  final SupplierLegalType legalType;

  /// La boutique que ce compte **opère**, qui n'est pas toujours la
  /// sienne : un collaborateur travaille dans celle de son patron
  /// (`supplier_collaborators`, `0093`). `null` pour un propriétaire —
  /// c'est alors [id], et le dire deux fois inviterait les deux valeurs
  /// à diverger.
  @override
  final String? operatesSupplierId;

  /// Ce que le patron lui a accordé : `products`, `orders`, `promotions`,
  /// `storefront`, `messages`, `reviews`. Vide pour un propriétaire, qui
  /// a tout sans qu'on ait à le lui donner.
  final List<String> _permissions;

  /// Ce que le patron lui a accordé : `products`, `orders`, `promotions`,
  /// `storefront`, `messages`, `reviews`. Vide pour un propriétaire, qui
  /// a tout sans qu'on ait à le lui donner.
  @override
  @JsonKey()
  List<String> get permissions {
    if (_permissions is EqualUnmodifiableListView) return _permissions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_permissions);
  }

  /// Vrai tant que le collaborateur n'a pas remplacé le mot de passe à
  /// usage unique que son patron lui a dicté (`0098`). Le routeur
  /// l'immobilise alors sur l'écran de changement : tant que ce code
  /// circule de vive voix, le compte n'est à personne.
  @override
  @JsonKey()
  final bool mustChangePassword;

  @override
  String toString() {
    return 'AppUser.supplierTiers(id: $id, displayName: $displayName, usernameOrPhone: $usernameOrPhone, phoneNumber: $phoneNumber, createdAt: $createdAt, businessName: $businessName, verificationStatus: $verificationStatus, city: $city, ratingAverage: $ratingAverage, ratingCount: $ratingCount, legalType: $legalType, operatesSupplierId: $operatesSupplierId, permissions: $permissions, mustChangePassword: $mustChangePassword)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierTiersUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.usernameOrPhone, usernameOrPhone) ||
                other.usernameOrPhone == usernameOrPhone) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.businessName, businessName) ||
                other.businessName == businessName) &&
            (identical(other.verificationStatus, verificationStatus) ||
                other.verificationStatus == verificationStatus) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.ratingAverage, ratingAverage) ||
                other.ratingAverage == ratingAverage) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.legalType, legalType) ||
                other.legalType == legalType) &&
            (identical(other.operatesSupplierId, operatesSupplierId) ||
                other.operatesSupplierId == operatesSupplierId) &&
            const DeepCollectionEquality().equals(
              other._permissions,
              _permissions,
            ) &&
            (identical(other.mustChangePassword, mustChangePassword) ||
                other.mustChangePassword == mustChangePassword));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    usernameOrPhone,
    phoneNumber,
    createdAt,
    businessName,
    verificationStatus,
    city,
    ratingAverage,
    ratingCount,
    legalType,
    operatesSupplierId,
    const DeepCollectionEquality().hash(_permissions),
    mustChangePassword,
  );

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierTiersUserImplCopyWith<_$SupplierTiersUserImpl> get copyWith =>
      __$$SupplierTiersUserImplCopyWithImpl<_$SupplierTiersUserImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )
    client,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )
    supplierTiers,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )
    courier,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )
    supplierPrincipal,
  }) {
    return supplierTiers(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      businessName,
      verificationStatus,
      city,
      ratingAverage,
      ratingCount,
      legalType,
      operatesSupplierId,
      permissions,
      mustChangePassword,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
  }) {
    return supplierTiers?.call(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      businessName,
      verificationStatus,
      city,
      ratingAverage,
      ratingCount,
      legalType,
      operatesSupplierId,
      permissions,
      mustChangePassword,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
    required TResult orElse(),
  }) {
    if (supplierTiers != null) {
      return supplierTiers(
        id,
        displayName,
        usernameOrPhone,
        phoneNumber,
        createdAt,
        businessName,
        verificationStatus,
        city,
        ratingAverage,
        ratingCount,
        legalType,
        operatesSupplierId,
        permissions,
        mustChangePassword,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ClientUser value) client,
    required TResult Function(SupplierTiersUser value) supplierTiers,
    required TResult Function(CourierUser value) courier,
    required TResult Function(SupplierPrincipalUser value) supplierPrincipal,
  }) {
    return supplierTiers(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ClientUser value)? client,
    TResult? Function(SupplierTiersUser value)? supplierTiers,
    TResult? Function(CourierUser value)? courier,
    TResult? Function(SupplierPrincipalUser value)? supplierPrincipal,
  }) {
    return supplierTiers?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ClientUser value)? client,
    TResult Function(SupplierTiersUser value)? supplierTiers,
    TResult Function(CourierUser value)? courier,
    TResult Function(SupplierPrincipalUser value)? supplierPrincipal,
    required TResult orElse(),
  }) {
    if (supplierTiers != null) {
      return supplierTiers(this);
    }
    return orElse();
  }
}

abstract class SupplierTiersUser implements AppUser {
  const factory SupplierTiersUser({
    required final String id,
    required final String displayName,
    required final String usernameOrPhone,
    required final String phoneNumber,
    required final DateTime createdAt,
    required final String businessName,
    required final VerificationStatus verificationStatus,
    required final String city,
    required final double ratingAverage,
    required final int ratingCount,
    required final SupplierLegalType legalType,
    final String? operatesSupplierId,
    final List<String> permissions,
    final bool mustChangePassword,
  }) = _$SupplierTiersUserImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get usernameOrPhone;
  @override
  String get phoneNumber;
  @override
  DateTime get createdAt;
  String get businessName;
  VerificationStatus get verificationStatus;
  String get city;
  double get ratingAverage;
  int get ratingCount;
  SupplierLegalType get legalType;

  /// La boutique que ce compte **opère**, qui n'est pas toujours la
  /// sienne : un collaborateur travaille dans celle de son patron
  /// (`supplier_collaborators`, `0093`). `null` pour un propriétaire —
  /// c'est alors [id], et le dire deux fois inviterait les deux valeurs
  /// à diverger.
  String? get operatesSupplierId;

  /// Ce que le patron lui a accordé : `products`, `orders`, `promotions`,
  /// `storefront`, `messages`, `reviews`. Vide pour un propriétaire, qui
  /// a tout sans qu'on ait à le lui donner.
  List<String> get permissions;

  /// Vrai tant que le collaborateur n'a pas remplacé le mot de passe à
  /// usage unique que son patron lui a dicté (`0098`). Le routeur
  /// l'immobilise alors sur l'écran de changement : tant que ce code
  /// circule de vive voix, le compte n'est à personne.
  bool get mustChangePassword;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierTiersUserImplCopyWith<_$SupplierTiersUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$CourierUserImplCopyWith<$Res>
    implements $AppUserCopyWith<$Res> {
  factory _$$CourierUserImplCopyWith(
    _$CourierUserImpl value,
    $Res Function(_$CourierUserImpl) then,
  ) = __$$CourierUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String usernameOrPhone,
    String phoneNumber,
    DateTime createdAt,
    CourierStatus courierStatus,
    String city,
    bool isOnline,
    String? vehicleLabel,
    DateTime? documentsSubmittedAt,
  });
}

/// @nodoc
class __$$CourierUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$CourierUserImpl>
    implements _$$CourierUserImplCopyWith<$Res> {
  __$$CourierUserImplCopyWithImpl(
    _$CourierUserImpl _value,
    $Res Function(_$CourierUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? usernameOrPhone = null,
    Object? phoneNumber = null,
    Object? createdAt = null,
    Object? courierStatus = null,
    Object? city = null,
    Object? isOnline = null,
    Object? vehicleLabel = freezed,
    Object? documentsSubmittedAt = freezed,
  }) {
    return _then(
      _$CourierUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        usernameOrPhone: null == usernameOrPhone
            ? _value.usernameOrPhone
            : usernameOrPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        courierStatus: null == courierStatus
            ? _value.courierStatus
            : courierStatus // ignore: cast_nullable_to_non_nullable
                  as CourierStatus,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        isOnline: null == isOnline
            ? _value.isOnline
            : isOnline // ignore: cast_nullable_to_non_nullable
                  as bool,
        vehicleLabel: freezed == vehicleLabel
            ? _value.vehicleLabel
            : vehicleLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        documentsSubmittedAt: freezed == documentsSubmittedAt
            ? _value.documentsSubmittedAt
            : documentsSubmittedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
      ),
    );
  }
}

/// @nodoc

class _$CourierUserImpl implements CourierUser {
  const _$CourierUserImpl({
    required this.id,
    required this.displayName,
    required this.usernameOrPhone,
    required this.phoneNumber,
    required this.createdAt,
    required this.courierStatus,
    required this.city,
    required this.isOnline,
    this.vehicleLabel,
    this.documentsSubmittedAt,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String usernameOrPhone;
  @override
  final String phoneNumber;
  @override
  final DateTime createdAt;
  @override
  final CourierStatus courierStatus;
  @override
  final String city;
  @override
  final bool isOnline;
  @override
  final String? vehicleLabel;

  /// Date de dépôt des pièces (`0105`). Nulle = rien n'a encore été
  /// envoyé : l'écran d'attente doit alors réclamer le dossier au lieu
  /// d'annoncer un examen qui n'a pas commencé.
  @override
  final DateTime? documentsSubmittedAt;

  @override
  String toString() {
    return 'AppUser.courier(id: $id, displayName: $displayName, usernameOrPhone: $usernameOrPhone, phoneNumber: $phoneNumber, createdAt: $createdAt, courierStatus: $courierStatus, city: $city, isOnline: $isOnline, vehicleLabel: $vehicleLabel, documentsSubmittedAt: $documentsSubmittedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.usernameOrPhone, usernameOrPhone) ||
                other.usernameOrPhone == usernameOrPhone) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.courierStatus, courierStatus) ||
                other.courierStatus == courierStatus) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.isOnline, isOnline) ||
                other.isOnline == isOnline) &&
            (identical(other.vehicleLabel, vehicleLabel) ||
                other.vehicleLabel == vehicleLabel) &&
            (identical(other.documentsSubmittedAt, documentsSubmittedAt) ||
                other.documentsSubmittedAt == documentsSubmittedAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    usernameOrPhone,
    phoneNumber,
    createdAt,
    courierStatus,
    city,
    isOnline,
    vehicleLabel,
    documentsSubmittedAt,
  );

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierUserImplCopyWith<_$CourierUserImpl> get copyWith =>
      __$$CourierUserImplCopyWithImpl<_$CourierUserImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )
    client,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )
    supplierTiers,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )
    courier,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )
    supplierPrincipal,
  }) {
    return courier(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      courierStatus,
      city,
      isOnline,
      vehicleLabel,
      documentsSubmittedAt,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
  }) {
    return courier?.call(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      courierStatus,
      city,
      isOnline,
      vehicleLabel,
      documentsSubmittedAt,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
    required TResult orElse(),
  }) {
    if (courier != null) {
      return courier(
        id,
        displayName,
        usernameOrPhone,
        phoneNumber,
        createdAt,
        courierStatus,
        city,
        isOnline,
        vehicleLabel,
        documentsSubmittedAt,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ClientUser value) client,
    required TResult Function(SupplierTiersUser value) supplierTiers,
    required TResult Function(CourierUser value) courier,
    required TResult Function(SupplierPrincipalUser value) supplierPrincipal,
  }) {
    return courier(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ClientUser value)? client,
    TResult? Function(SupplierTiersUser value)? supplierTiers,
    TResult? Function(CourierUser value)? courier,
    TResult? Function(SupplierPrincipalUser value)? supplierPrincipal,
  }) {
    return courier?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ClientUser value)? client,
    TResult Function(SupplierTiersUser value)? supplierTiers,
    TResult Function(CourierUser value)? courier,
    TResult Function(SupplierPrincipalUser value)? supplierPrincipal,
    required TResult orElse(),
  }) {
    if (courier != null) {
      return courier(this);
    }
    return orElse();
  }
}

abstract class CourierUser implements AppUser {
  const factory CourierUser({
    required final String id,
    required final String displayName,
    required final String usernameOrPhone,
    required final String phoneNumber,
    required final DateTime createdAt,
    required final CourierStatus courierStatus,
    required final String city,
    required final bool isOnline,
    final String? vehicleLabel,
    final DateTime? documentsSubmittedAt,
  }) = _$CourierUserImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get usernameOrPhone;
  @override
  String get phoneNumber;
  @override
  DateTime get createdAt;
  CourierStatus get courierStatus;
  String get city;
  bool get isOnline;
  String? get vehicleLabel;

  /// Date de dépôt des pièces (`0105`). Nulle = rien n'a encore été
  /// envoyé : l'écran d'attente doit alors réclamer le dossier au lieu
  /// d'annoncer un examen qui n'a pas commencé.
  DateTime? get documentsSubmittedAt;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierUserImplCopyWith<_$CourierUserImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SupplierPrincipalUserImplCopyWith<$Res>
    implements $AppUserCopyWith<$Res> {
  factory _$$SupplierPrincipalUserImplCopyWith(
    _$SupplierPrincipalUserImpl value,
    $Res Function(_$SupplierPrincipalUserImpl) then,
  ) = __$$SupplierPrincipalUserImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String usernameOrPhone,
    String phoneNumber,
    DateTime createdAt,
    StaffRole staffRole,
  });
}

/// @nodoc
class __$$SupplierPrincipalUserImplCopyWithImpl<$Res>
    extends _$AppUserCopyWithImpl<$Res, _$SupplierPrincipalUserImpl>
    implements _$$SupplierPrincipalUserImplCopyWith<$Res> {
  __$$SupplierPrincipalUserImplCopyWithImpl(
    _$SupplierPrincipalUserImpl _value,
    $Res Function(_$SupplierPrincipalUserImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? usernameOrPhone = null,
    Object? phoneNumber = null,
    Object? createdAt = null,
    Object? staffRole = null,
  }) {
    return _then(
      _$SupplierPrincipalUserImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        usernameOrPhone: null == usernameOrPhone
            ? _value.usernameOrPhone
            : usernameOrPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        staffRole: null == staffRole
            ? _value.staffRole
            : staffRole // ignore: cast_nullable_to_non_nullable
                  as StaffRole,
      ),
    );
  }
}

/// @nodoc

class _$SupplierPrincipalUserImpl implements SupplierPrincipalUser {
  const _$SupplierPrincipalUserImpl({
    required this.id,
    required this.displayName,
    required this.usernameOrPhone,
    required this.phoneNumber,
    required this.createdAt,
    required this.staffRole,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String usernameOrPhone;
  @override
  final String phoneNumber;
  @override
  final DateTime createdAt;
  @override
  final StaffRole staffRole;

  @override
  String toString() {
    return 'AppUser.supplierPrincipal(id: $id, displayName: $displayName, usernameOrPhone: $usernameOrPhone, phoneNumber: $phoneNumber, createdAt: $createdAt, staffRole: $staffRole)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SupplierPrincipalUserImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.usernameOrPhone, usernameOrPhone) ||
                other.usernameOrPhone == usernameOrPhone) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.staffRole, staffRole) ||
                other.staffRole == staffRole));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    usernameOrPhone,
    phoneNumber,
    createdAt,
    staffRole,
  );

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SupplierPrincipalUserImplCopyWith<_$SupplierPrincipalUserImpl>
  get copyWith =>
      __$$SupplierPrincipalUserImplCopyWithImpl<_$SupplierPrincipalUserImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )
    client,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )
    supplierTiers,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )
    courier,
    required TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )
    supplierPrincipal,
  }) {
    return supplierPrincipal(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      staffRole,
    );
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult? Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
  }) {
    return supplierPrincipal?.call(
      id,
      displayName,
      usernameOrPhone,
      phoneNumber,
      createdAt,
      staffRole,
    );
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String? defaultAddressId,
    )?
    client,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      String businessName,
      VerificationStatus verificationStatus,
      String city,
      double ratingAverage,
      int ratingCount,
      SupplierLegalType legalType,
      String? operatesSupplierId,
      List<String> permissions,
      bool mustChangePassword,
    )?
    supplierTiers,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      CourierStatus courierStatus,
      String city,
      bool isOnline,
      String? vehicleLabel,
      DateTime? documentsSubmittedAt,
    )?
    courier,
    TResult Function(
      String id,
      String displayName,
      String usernameOrPhone,
      String phoneNumber,
      DateTime createdAt,
      StaffRole staffRole,
    )?
    supplierPrincipal,
    required TResult orElse(),
  }) {
    if (supplierPrincipal != null) {
      return supplierPrincipal(
        id,
        displayName,
        usernameOrPhone,
        phoneNumber,
        createdAt,
        staffRole,
      );
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ClientUser value) client,
    required TResult Function(SupplierTiersUser value) supplierTiers,
    required TResult Function(CourierUser value) courier,
    required TResult Function(SupplierPrincipalUser value) supplierPrincipal,
  }) {
    return supplierPrincipal(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ClientUser value)? client,
    TResult? Function(SupplierTiersUser value)? supplierTiers,
    TResult? Function(CourierUser value)? courier,
    TResult? Function(SupplierPrincipalUser value)? supplierPrincipal,
  }) {
    return supplierPrincipal?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ClientUser value)? client,
    TResult Function(SupplierTiersUser value)? supplierTiers,
    TResult Function(CourierUser value)? courier,
    TResult Function(SupplierPrincipalUser value)? supplierPrincipal,
    required TResult orElse(),
  }) {
    if (supplierPrincipal != null) {
      return supplierPrincipal(this);
    }
    return orElse();
  }
}

abstract class SupplierPrincipalUser implements AppUser {
  const factory SupplierPrincipalUser({
    required final String id,
    required final String displayName,
    required final String usernameOrPhone,
    required final String phoneNumber,
    required final DateTime createdAt,
    required final StaffRole staffRole,
  }) = _$SupplierPrincipalUserImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get usernameOrPhone;
  @override
  String get phoneNumber;
  @override
  DateTime get createdAt;
  StaffRole get staffRole;

  /// Create a copy of AppUser
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SupplierPrincipalUserImplCopyWith<_$SupplierPrincipalUserImpl>
  get copyWith => throw _privateConstructorUsedError;
}
