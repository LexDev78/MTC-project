// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'courier_delivery.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$DeliveryItem {
  String get productName => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  String? get variantName => throw _privateConstructorUsedError;

  /// Create a copy of DeliveryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DeliveryItemCopyWith<DeliveryItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DeliveryItemCopyWith<$Res> {
  factory $DeliveryItemCopyWith(
    DeliveryItem value,
    $Res Function(DeliveryItem) then,
  ) = _$DeliveryItemCopyWithImpl<$Res, DeliveryItem>;
  @useResult
  $Res call({String productName, int quantity, String? variantName});
}

/// @nodoc
class _$DeliveryItemCopyWithImpl<$Res, $Val extends DeliveryItem>
    implements $DeliveryItemCopyWith<$Res> {
  _$DeliveryItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DeliveryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productName = null,
    Object? quantity = null,
    Object? variantName = freezed,
  }) {
    return _then(
      _value.copyWith(
            productName: null == productName
                ? _value.productName
                : productName // ignore: cast_nullable_to_non_nullable
                      as String,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            variantName: freezed == variantName
                ? _value.variantName
                : variantName // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$DeliveryItemImplCopyWith<$Res>
    implements $DeliveryItemCopyWith<$Res> {
  factory _$$DeliveryItemImplCopyWith(
    _$DeliveryItemImpl value,
    $Res Function(_$DeliveryItemImpl) then,
  ) = __$$DeliveryItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String productName, int quantity, String? variantName});
}

/// @nodoc
class __$$DeliveryItemImplCopyWithImpl<$Res>
    extends _$DeliveryItemCopyWithImpl<$Res, _$DeliveryItemImpl>
    implements _$$DeliveryItemImplCopyWith<$Res> {
  __$$DeliveryItemImplCopyWithImpl(
    _$DeliveryItemImpl _value,
    $Res Function(_$DeliveryItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of DeliveryItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productName = null,
    Object? quantity = null,
    Object? variantName = freezed,
  }) {
    return _then(
      _$DeliveryItemImpl(
        productName: null == productName
            ? _value.productName
            : productName // ignore: cast_nullable_to_non_nullable
                  as String,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        variantName: freezed == variantName
            ? _value.variantName
            : variantName // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$DeliveryItemImpl implements _DeliveryItem {
  const _$DeliveryItemImpl({
    required this.productName,
    required this.quantity,
    this.variantName,
  });

  @override
  final String productName;
  @override
  final int quantity;
  @override
  final String? variantName;

  @override
  String toString() {
    return 'DeliveryItem(productName: $productName, quantity: $quantity, variantName: $variantName)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DeliveryItemImpl &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.variantName, variantName) ||
                other.variantName == variantName));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, productName, quantity, variantName);

  /// Create a copy of DeliveryItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DeliveryItemImplCopyWith<_$DeliveryItemImpl> get copyWith =>
      __$$DeliveryItemImplCopyWithImpl<_$DeliveryItemImpl>(this, _$identity);
}

abstract class _DeliveryItem implements DeliveryItem {
  const factory _DeliveryItem({
    required final String productName,
    required final int quantity,
    final String? variantName,
  }) = _$DeliveryItemImpl;

  @override
  String get productName;
  @override
  int get quantity;
  @override
  String? get variantName;

  /// Create a copy of DeliveryItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DeliveryItemImplCopyWith<_$DeliveryItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CourierDelivery {
  String get id => throw _privateConstructorUsedError;
  String get orderId => throw _privateConstructorUsedError;
  String get supplierGroupId => throw _privateConstructorUsedError;
  DeliveryStatus get status => throw _privateConstructorUsedError;

  /// Fin de la fenêtre de réponse quand la course est proposée — passé ce
  /// délai elle part au livreur suivant.
  DateTime? get offerExpiresAt =>
      throw _privateConstructorUsedError; // ---- retrait ----------------------------------------------------------
  String get supplierName => throw _privateConstructorUsedError;
  String? get supplierAddress => throw _privateConstructorUsedError;
  String get supplierCity => throw _privateConstructorUsedError;
  double? get supplierLatitude => throw _privateConstructorUsedError;
  double? get supplierLongitude => throw _privateConstructorUsedError;
  List<String> get supplierPhones =>
      throw _privateConstructorUsedError; // ---- remise -----------------------------------------------------------
  String get clientName => throw _privateConstructorUsedError;
  String get clientPhone => throw _privateConstructorUsedError;
  String? get clientAlternatePhone => throw _privateConstructorUsedError;
  String get deliveryAddressLabel => throw _privateConstructorUsedError;
  String get deliveryCity => throw _privateConstructorUsedError;

  /// Indications libres saisies par le client (étage, repère, portail…).
  String get deliveryDetails => throw _privateConstructorUsedError;
  double get deliveryLatitude => throw _privateConstructorUsedError;
  double get deliveryLongitude =>
      throw _privateConstructorUsedError; // ---- marchandise et argent --------------------------------------------
  List<DeliveryItem> get items => throw _privateConstructorUsedError;
  int get deliveryFeeFcfa => throw _privateConstructorUsedError;
  int get subtotalFcfa => throw _privateConstructorUsedError;

  /// Paiement à la livraison : le livreur encaisse. Le distinguer n'est pas
  /// cosmétique — c'est la différence entre remettre un colis et repartir
  /// avec de l'argent.
  bool get collectOnDelivery => throw _privateConstructorUsedError;

  /// Create a copy of CourierDelivery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CourierDeliveryCopyWith<CourierDelivery> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CourierDeliveryCopyWith<$Res> {
  factory $CourierDeliveryCopyWith(
    CourierDelivery value,
    $Res Function(CourierDelivery) then,
  ) = _$CourierDeliveryCopyWithImpl<$Res, CourierDelivery>;
  @useResult
  $Res call({
    String id,
    String orderId,
    String supplierGroupId,
    DeliveryStatus status,
    DateTime? offerExpiresAt,
    String supplierName,
    String? supplierAddress,
    String supplierCity,
    double? supplierLatitude,
    double? supplierLongitude,
    List<String> supplierPhones,
    String clientName,
    String clientPhone,
    String? clientAlternatePhone,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
    List<DeliveryItem> items,
    int deliveryFeeFcfa,
    int subtotalFcfa,
    bool collectOnDelivery,
  });
}

/// @nodoc
class _$CourierDeliveryCopyWithImpl<$Res, $Val extends CourierDelivery>
    implements $CourierDeliveryCopyWith<$Res> {
  _$CourierDeliveryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CourierDelivery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? supplierGroupId = null,
    Object? status = null,
    Object? offerExpiresAt = freezed,
    Object? supplierName = null,
    Object? supplierAddress = freezed,
    Object? supplierCity = null,
    Object? supplierLatitude = freezed,
    Object? supplierLongitude = freezed,
    Object? supplierPhones = null,
    Object? clientName = null,
    Object? clientPhone = null,
    Object? clientAlternatePhone = freezed,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? items = null,
    Object? deliveryFeeFcfa = null,
    Object? subtotalFcfa = null,
    Object? collectOnDelivery = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            orderId: null == orderId
                ? _value.orderId
                : orderId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierGroupId: null == supplierGroupId
                ? _value.supplierGroupId
                : supplierGroupId // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as DeliveryStatus,
            offerExpiresAt: freezed == offerExpiresAt
                ? _value.offerExpiresAt
                : offerExpiresAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            supplierName: null == supplierName
                ? _value.supplierName
                : supplierName // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierAddress: freezed == supplierAddress
                ? _value.supplierAddress
                : supplierAddress // ignore: cast_nullable_to_non_nullable
                      as String?,
            supplierCity: null == supplierCity
                ? _value.supplierCity
                : supplierCity // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierLatitude: freezed == supplierLatitude
                ? _value.supplierLatitude
                : supplierLatitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            supplierLongitude: freezed == supplierLongitude
                ? _value.supplierLongitude
                : supplierLongitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            supplierPhones: null == supplierPhones
                ? _value.supplierPhones
                : supplierPhones // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            clientName: null == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                      as String,
            clientPhone: null == clientPhone
                ? _value.clientPhone
                : clientPhone // ignore: cast_nullable_to_non_nullable
                      as String,
            clientAlternatePhone: freezed == clientAlternatePhone
                ? _value.clientAlternatePhone
                : clientAlternatePhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            deliveryAddressLabel: null == deliveryAddressLabel
                ? _value.deliveryAddressLabel
                : deliveryAddressLabel // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryCity: null == deliveryCity
                ? _value.deliveryCity
                : deliveryCity // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryDetails: null == deliveryDetails
                ? _value.deliveryDetails
                : deliveryDetails // ignore: cast_nullable_to_non_nullable
                      as String,
            deliveryLatitude: null == deliveryLatitude
                ? _value.deliveryLatitude
                : deliveryLatitude // ignore: cast_nullable_to_non_nullable
                      as double,
            deliveryLongitude: null == deliveryLongitude
                ? _value.deliveryLongitude
                : deliveryLongitude // ignore: cast_nullable_to_non_nullable
                      as double,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<DeliveryItem>,
            deliveryFeeFcfa: null == deliveryFeeFcfa
                ? _value.deliveryFeeFcfa
                : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            subtotalFcfa: null == subtotalFcfa
                ? _value.subtotalFcfa
                : subtotalFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            collectOnDelivery: null == collectOnDelivery
                ? _value.collectOnDelivery
                : collectOnDelivery // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CourierDeliveryImplCopyWith<$Res>
    implements $CourierDeliveryCopyWith<$Res> {
  factory _$$CourierDeliveryImplCopyWith(
    _$CourierDeliveryImpl value,
    $Res Function(_$CourierDeliveryImpl) then,
  ) = __$$CourierDeliveryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String orderId,
    String supplierGroupId,
    DeliveryStatus status,
    DateTime? offerExpiresAt,
    String supplierName,
    String? supplierAddress,
    String supplierCity,
    double? supplierLatitude,
    double? supplierLongitude,
    List<String> supplierPhones,
    String clientName,
    String clientPhone,
    String? clientAlternatePhone,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
    List<DeliveryItem> items,
    int deliveryFeeFcfa,
    int subtotalFcfa,
    bool collectOnDelivery,
  });
}

/// @nodoc
class __$$CourierDeliveryImplCopyWithImpl<$Res>
    extends _$CourierDeliveryCopyWithImpl<$Res, _$CourierDeliveryImpl>
    implements _$$CourierDeliveryImplCopyWith<$Res> {
  __$$CourierDeliveryImplCopyWithImpl(
    _$CourierDeliveryImpl _value,
    $Res Function(_$CourierDeliveryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CourierDelivery
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? supplierGroupId = null,
    Object? status = null,
    Object? offerExpiresAt = freezed,
    Object? supplierName = null,
    Object? supplierAddress = freezed,
    Object? supplierCity = null,
    Object? supplierLatitude = freezed,
    Object? supplierLongitude = freezed,
    Object? supplierPhones = null,
    Object? clientName = null,
    Object? clientPhone = null,
    Object? clientAlternatePhone = freezed,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? items = null,
    Object? deliveryFeeFcfa = null,
    Object? subtotalFcfa = null,
    Object? collectOnDelivery = null,
  }) {
    return _then(
      _$CourierDeliveryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        orderId: null == orderId
            ? _value.orderId
            : orderId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierGroupId: null == supplierGroupId
            ? _value.supplierGroupId
            : supplierGroupId // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as DeliveryStatus,
        offerExpiresAt: freezed == offerExpiresAt
            ? _value.offerExpiresAt
            : offerExpiresAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        supplierName: null == supplierName
            ? _value.supplierName
            : supplierName // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierAddress: freezed == supplierAddress
            ? _value.supplierAddress
            : supplierAddress // ignore: cast_nullable_to_non_nullable
                  as String?,
        supplierCity: null == supplierCity
            ? _value.supplierCity
            : supplierCity // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierLatitude: freezed == supplierLatitude
            ? _value.supplierLatitude
            : supplierLatitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        supplierLongitude: freezed == supplierLongitude
            ? _value.supplierLongitude
            : supplierLongitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        supplierPhones: null == supplierPhones
            ? _value._supplierPhones
            : supplierPhones // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        clientName: null == clientName
            ? _value.clientName
            : clientName // ignore: cast_nullable_to_non_nullable
                  as String,
        clientPhone: null == clientPhone
            ? _value.clientPhone
            : clientPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        clientAlternatePhone: freezed == clientAlternatePhone
            ? _value.clientAlternatePhone
            : clientAlternatePhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        deliveryAddressLabel: null == deliveryAddressLabel
            ? _value.deliveryAddressLabel
            : deliveryAddressLabel // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryCity: null == deliveryCity
            ? _value.deliveryCity
            : deliveryCity // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryDetails: null == deliveryDetails
            ? _value.deliveryDetails
            : deliveryDetails // ignore: cast_nullable_to_non_nullable
                  as String,
        deliveryLatitude: null == deliveryLatitude
            ? _value.deliveryLatitude
            : deliveryLatitude // ignore: cast_nullable_to_non_nullable
                  as double,
        deliveryLongitude: null == deliveryLongitude
            ? _value.deliveryLongitude
            : deliveryLongitude // ignore: cast_nullable_to_non_nullable
                  as double,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<DeliveryItem>,
        deliveryFeeFcfa: null == deliveryFeeFcfa
            ? _value.deliveryFeeFcfa
            : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        subtotalFcfa: null == subtotalFcfa
            ? _value.subtotalFcfa
            : subtotalFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        collectOnDelivery: null == collectOnDelivery
            ? _value.collectOnDelivery
            : collectOnDelivery // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$CourierDeliveryImpl implements _CourierDelivery {
  const _$CourierDeliveryImpl({
    required this.id,
    required this.orderId,
    required this.supplierGroupId,
    required this.status,
    this.offerExpiresAt,
    required this.supplierName,
    this.supplierAddress,
    required this.supplierCity,
    this.supplierLatitude,
    this.supplierLongitude,
    final List<String> supplierPhones = const [],
    required this.clientName,
    required this.clientPhone,
    this.clientAlternatePhone,
    required this.deliveryAddressLabel,
    required this.deliveryCity,
    required this.deliveryDetails,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    final List<DeliveryItem> items = const [],
    required this.deliveryFeeFcfa,
    required this.subtotalFcfa,
    required this.collectOnDelivery,
  }) : _supplierPhones = supplierPhones,
       _items = items;

  @override
  final String id;
  @override
  final String orderId;
  @override
  final String supplierGroupId;
  @override
  final DeliveryStatus status;

  /// Fin de la fenêtre de réponse quand la course est proposée — passé ce
  /// délai elle part au livreur suivant.
  @override
  final DateTime? offerExpiresAt;
  // ---- retrait ----------------------------------------------------------
  @override
  final String supplierName;
  @override
  final String? supplierAddress;
  @override
  final String supplierCity;
  @override
  final double? supplierLatitude;
  @override
  final double? supplierLongitude;
  final List<String> _supplierPhones;
  @override
  @JsonKey()
  List<String> get supplierPhones {
    if (_supplierPhones is EqualUnmodifiableListView) return _supplierPhones;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supplierPhones);
  }

  // ---- remise -----------------------------------------------------------
  @override
  final String clientName;
  @override
  final String clientPhone;
  @override
  final String? clientAlternatePhone;
  @override
  final String deliveryAddressLabel;
  @override
  final String deliveryCity;

  /// Indications libres saisies par le client (étage, repère, portail…).
  @override
  final String deliveryDetails;
  @override
  final double deliveryLatitude;
  @override
  final double deliveryLongitude;
  // ---- marchandise et argent --------------------------------------------
  final List<DeliveryItem> _items;
  // ---- marchandise et argent --------------------------------------------
  @override
  @JsonKey()
  List<DeliveryItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int deliveryFeeFcfa;
  @override
  final int subtotalFcfa;

  /// Paiement à la livraison : le livreur encaisse. Le distinguer n'est pas
  /// cosmétique — c'est la différence entre remettre un colis et repartir
  /// avec de l'argent.
  @override
  final bool collectOnDelivery;

  @override
  String toString() {
    return 'CourierDelivery(id: $id, orderId: $orderId, supplierGroupId: $supplierGroupId, status: $status, offerExpiresAt: $offerExpiresAt, supplierName: $supplierName, supplierAddress: $supplierAddress, supplierCity: $supplierCity, supplierLatitude: $supplierLatitude, supplierLongitude: $supplierLongitude, supplierPhones: $supplierPhones, clientName: $clientName, clientPhone: $clientPhone, clientAlternatePhone: $clientAlternatePhone, deliveryAddressLabel: $deliveryAddressLabel, deliveryCity: $deliveryCity, deliveryDetails: $deliveryDetails, deliveryLatitude: $deliveryLatitude, deliveryLongitude: $deliveryLongitude, items: $items, deliveryFeeFcfa: $deliveryFeeFcfa, subtotalFcfa: $subtotalFcfa, collectOnDelivery: $collectOnDelivery)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CourierDeliveryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.supplierGroupId, supplierGroupId) ||
                other.supplierGroupId == supplierGroupId) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.offerExpiresAt, offerExpiresAt) ||
                other.offerExpiresAt == offerExpiresAt) &&
            (identical(other.supplierName, supplierName) ||
                other.supplierName == supplierName) &&
            (identical(other.supplierAddress, supplierAddress) ||
                other.supplierAddress == supplierAddress) &&
            (identical(other.supplierCity, supplierCity) ||
                other.supplierCity == supplierCity) &&
            (identical(other.supplierLatitude, supplierLatitude) ||
                other.supplierLatitude == supplierLatitude) &&
            (identical(other.supplierLongitude, supplierLongitude) ||
                other.supplierLongitude == supplierLongitude) &&
            const DeepCollectionEquality().equals(
              other._supplierPhones,
              _supplierPhones,
            ) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            (identical(other.clientPhone, clientPhone) ||
                other.clientPhone == clientPhone) &&
            (identical(other.clientAlternatePhone, clientAlternatePhone) ||
                other.clientAlternatePhone == clientAlternatePhone) &&
            (identical(other.deliveryAddressLabel, deliveryAddressLabel) ||
                other.deliveryAddressLabel == deliveryAddressLabel) &&
            (identical(other.deliveryCity, deliveryCity) ||
                other.deliveryCity == deliveryCity) &&
            (identical(other.deliveryDetails, deliveryDetails) ||
                other.deliveryDetails == deliveryDetails) &&
            (identical(other.deliveryLatitude, deliveryLatitude) ||
                other.deliveryLatitude == deliveryLatitude) &&
            (identical(other.deliveryLongitude, deliveryLongitude) ||
                other.deliveryLongitude == deliveryLongitude) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.deliveryFeeFcfa, deliveryFeeFcfa) ||
                other.deliveryFeeFcfa == deliveryFeeFcfa) &&
            (identical(other.subtotalFcfa, subtotalFcfa) ||
                other.subtotalFcfa == subtotalFcfa) &&
            (identical(other.collectOnDelivery, collectOnDelivery) ||
                other.collectOnDelivery == collectOnDelivery));
  }

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    orderId,
    supplierGroupId,
    status,
    offerExpiresAt,
    supplierName,
    supplierAddress,
    supplierCity,
    supplierLatitude,
    supplierLongitude,
    const DeepCollectionEquality().hash(_supplierPhones),
    clientName,
    clientPhone,
    clientAlternatePhone,
    deliveryAddressLabel,
    deliveryCity,
    deliveryDetails,
    deliveryLatitude,
    deliveryLongitude,
    const DeepCollectionEquality().hash(_items),
    deliveryFeeFcfa,
    subtotalFcfa,
    collectOnDelivery,
  ]);

  /// Create a copy of CourierDelivery
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CourierDeliveryImplCopyWith<_$CourierDeliveryImpl> get copyWith =>
      __$$CourierDeliveryImplCopyWithImpl<_$CourierDeliveryImpl>(
        this,
        _$identity,
      );
}

abstract class _CourierDelivery implements CourierDelivery {
  const factory _CourierDelivery({
    required final String id,
    required final String orderId,
    required final String supplierGroupId,
    required final DeliveryStatus status,
    final DateTime? offerExpiresAt,
    required final String supplierName,
    final String? supplierAddress,
    required final String supplierCity,
    final double? supplierLatitude,
    final double? supplierLongitude,
    final List<String> supplierPhones,
    required final String clientName,
    required final String clientPhone,
    final String? clientAlternatePhone,
    required final String deliveryAddressLabel,
    required final String deliveryCity,
    required final String deliveryDetails,
    required final double deliveryLatitude,
    required final double deliveryLongitude,
    final List<DeliveryItem> items,
    required final int deliveryFeeFcfa,
    required final int subtotalFcfa,
    required final bool collectOnDelivery,
  }) = _$CourierDeliveryImpl;

  @override
  String get id;
  @override
  String get orderId;
  @override
  String get supplierGroupId;
  @override
  DeliveryStatus get status;

  /// Fin de la fenêtre de réponse quand la course est proposée — passé ce
  /// délai elle part au livreur suivant.
  @override
  DateTime? get offerExpiresAt; // ---- retrait ----------------------------------------------------------
  @override
  String get supplierName;
  @override
  String? get supplierAddress;
  @override
  String get supplierCity;
  @override
  double? get supplierLatitude;
  @override
  double? get supplierLongitude;
  @override
  List<String> get supplierPhones; // ---- remise -----------------------------------------------------------
  @override
  String get clientName;
  @override
  String get clientPhone;
  @override
  String? get clientAlternatePhone;
  @override
  String get deliveryAddressLabel;
  @override
  String get deliveryCity;

  /// Indications libres saisies par le client (étage, repère, portail…).
  @override
  String get deliveryDetails;
  @override
  double get deliveryLatitude;
  @override
  double get deliveryLongitude; // ---- marchandise et argent --------------------------------------------
  @override
  List<DeliveryItem> get items;
  @override
  int get deliveryFeeFcfa;
  @override
  int get subtotalFcfa;

  /// Paiement à la livraison : le livreur encaisse. Le distinguer n'est pas
  /// cosmétique — c'est la différence entre remettre un colis et repartir
  /// avec de l'argent.
  @override
  bool get collectOnDelivery;

  /// Create a copy of CourierDelivery
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CourierDeliveryImplCopyWith<_$CourierDeliveryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PendingCourier {
  String get id => throw _privateConstructorUsedError;
  String get displayName => throw _privateConstructorUsedError;
  String get phoneNumber => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String? get vehicleLabel => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Create a copy of PendingCourier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PendingCourierCopyWith<PendingCourier> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PendingCourierCopyWith<$Res> {
  factory $PendingCourierCopyWith(
    PendingCourier value,
    $Res Function(PendingCourier) then,
  ) = _$PendingCourierCopyWithImpl<$Res, PendingCourier>;
  @useResult
  $Res call({
    String id,
    String displayName,
    String phoneNumber,
    String city,
    String? vehicleLabel,
    DateTime createdAt,
  });
}

/// @nodoc
class _$PendingCourierCopyWithImpl<$Res, $Val extends PendingCourier>
    implements $PendingCourierCopyWith<$Res> {
  _$PendingCourierCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PendingCourier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? phoneNumber = null,
    Object? city = null,
    Object? vehicleLabel = freezed,
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
            phoneNumber: null == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            vehicleLabel: freezed == vehicleLabel
                ? _value.vehicleLabel
                : vehicleLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
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
abstract class _$$PendingCourierImplCopyWith<$Res>
    implements $PendingCourierCopyWith<$Res> {
  factory _$$PendingCourierImplCopyWith(
    _$PendingCourierImpl value,
    $Res Function(_$PendingCourierImpl) then,
  ) = __$$PendingCourierImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String displayName,
    String phoneNumber,
    String city,
    String? vehicleLabel,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$PendingCourierImplCopyWithImpl<$Res>
    extends _$PendingCourierCopyWithImpl<$Res, _$PendingCourierImpl>
    implements _$$PendingCourierImplCopyWith<$Res> {
  __$$PendingCourierImplCopyWithImpl(
    _$PendingCourierImpl _value,
    $Res Function(_$PendingCourierImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PendingCourier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = null,
    Object? phoneNumber = null,
    Object? city = null,
    Object? vehicleLabel = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$PendingCourierImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        vehicleLabel: freezed == vehicleLabel
            ? _value.vehicleLabel
            : vehicleLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc

class _$PendingCourierImpl implements _PendingCourier {
  const _$PendingCourierImpl({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    required this.city,
    this.vehicleLabel,
    required this.createdAt,
  });

  @override
  final String id;
  @override
  final String displayName;
  @override
  final String phoneNumber;
  @override
  final String city;
  @override
  final String? vehicleLabel;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'PendingCourier(id: $id, displayName: $displayName, phoneNumber: $phoneNumber, city: $city, vehicleLabel: $vehicleLabel, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PendingCourierImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.vehicleLabel, vehicleLabel) ||
                other.vehicleLabel == vehicleLabel) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    displayName,
    phoneNumber,
    city,
    vehicleLabel,
    createdAt,
  );

  /// Create a copy of PendingCourier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PendingCourierImplCopyWith<_$PendingCourierImpl> get copyWith =>
      __$$PendingCourierImplCopyWithImpl<_$PendingCourierImpl>(
        this,
        _$identity,
      );
}

abstract class _PendingCourier implements PendingCourier {
  const factory _PendingCourier({
    required final String id,
    required final String displayName,
    required final String phoneNumber,
    required final String city,
    final String? vehicleLabel,
    required final DateTime createdAt,
  }) = _$PendingCourierImpl;

  @override
  String get id;
  @override
  String get displayName;
  @override
  String get phoneNumber;
  @override
  String get city;
  @override
  String? get vehicleLabel;
  @override
  DateTime get createdAt;

  /// Create a copy of PendingCourier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PendingCourierImplCopyWith<_$PendingCourierImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
