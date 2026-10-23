// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) {
  return _OrderItem.fromJson(json);
}

/// @nodoc
mixin _$OrderItem {
  String get productId => throw _privateConstructorUsedError;
  String get productNameSnapshot => throw _privateConstructorUsedError;
  int get unitPriceFcfaSnapshot => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;

  /// Which variant was ordered, if the product had variants at order
  /// time — `null` for a variant-less product.
  String? get variantId => throw _privateConstructorUsedError;
  String? get variantNameSnapshot => throw _privateConstructorUsedError;

  /// Serializes this OrderItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderItemCopyWith<OrderItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderItemCopyWith<$Res> {
  factory $OrderItemCopyWith(OrderItem value, $Res Function(OrderItem) then) =
      _$OrderItemCopyWithImpl<$Res, OrderItem>;
  @useResult
  $Res call({
    String productId,
    String productNameSnapshot,
    int unitPriceFcfaSnapshot,
    int quantity,
    String? variantId,
    String? variantNameSnapshot,
  });
}

/// @nodoc
class _$OrderItemCopyWithImpl<$Res, $Val extends OrderItem>
    implements $OrderItemCopyWith<$Res> {
  _$OrderItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? productNameSnapshot = null,
    Object? unitPriceFcfaSnapshot = null,
    Object? quantity = null,
    Object? variantId = freezed,
    Object? variantNameSnapshot = freezed,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            productNameSnapshot: null == productNameSnapshot
                ? _value.productNameSnapshot
                : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            unitPriceFcfaSnapshot: null == unitPriceFcfaSnapshot
                ? _value.unitPriceFcfaSnapshot
                : unitPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                      as int,
            quantity: null == quantity
                ? _value.quantity
                : quantity // ignore: cast_nullable_to_non_nullable
                      as int,
            variantId: freezed == variantId
                ? _value.variantId
                : variantId // ignore: cast_nullable_to_non_nullable
                      as String?,
            variantNameSnapshot: freezed == variantNameSnapshot
                ? _value.variantNameSnapshot
                : variantNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderItemImplCopyWith<$Res>
    implements $OrderItemCopyWith<$Res> {
  factory _$$OrderItemImplCopyWith(
    _$OrderItemImpl value,
    $Res Function(_$OrderItemImpl) then,
  ) = __$$OrderItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String productId,
    String productNameSnapshot,
    int unitPriceFcfaSnapshot,
    int quantity,
    String? variantId,
    String? variantNameSnapshot,
  });
}

/// @nodoc
class __$$OrderItemImplCopyWithImpl<$Res>
    extends _$OrderItemCopyWithImpl<$Res, _$OrderItemImpl>
    implements _$$OrderItemImplCopyWith<$Res> {
  __$$OrderItemImplCopyWithImpl(
    _$OrderItemImpl _value,
    $Res Function(_$OrderItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? productNameSnapshot = null,
    Object? unitPriceFcfaSnapshot = null,
    Object? quantity = null,
    Object? variantId = freezed,
    Object? variantNameSnapshot = freezed,
  }) {
    return _then(
      _$OrderItemImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        productNameSnapshot: null == productNameSnapshot
            ? _value.productNameSnapshot
            : productNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        unitPriceFcfaSnapshot: null == unitPriceFcfaSnapshot
            ? _value.unitPriceFcfaSnapshot
            : unitPriceFcfaSnapshot // ignore: cast_nullable_to_non_nullable
                  as int,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        variantId: freezed == variantId
            ? _value.variantId
            : variantId // ignore: cast_nullable_to_non_nullable
                  as String?,
        variantNameSnapshot: freezed == variantNameSnapshot
            ? _value.variantNameSnapshot
            : variantNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderItemImpl implements _OrderItem {
  const _$OrderItemImpl({
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPriceFcfaSnapshot,
    required this.quantity,
    this.variantId,
    this.variantNameSnapshot,
  });

  factory _$OrderItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderItemImplFromJson(json);

  @override
  final String productId;
  @override
  final String productNameSnapshot;
  @override
  final int unitPriceFcfaSnapshot;
  @override
  final int quantity;

  /// Which variant was ordered, if the product had variants at order
  /// time — `null` for a variant-less product.
  @override
  final String? variantId;
  @override
  final String? variantNameSnapshot;

  @override
  String toString() {
    return 'OrderItem(productId: $productId, productNameSnapshot: $productNameSnapshot, unitPriceFcfaSnapshot: $unitPriceFcfaSnapshot, quantity: $quantity, variantId: $variantId, variantNameSnapshot: $variantNameSnapshot)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderItemImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.productNameSnapshot, productNameSnapshot) ||
                other.productNameSnapshot == productNameSnapshot) &&
            (identical(other.unitPriceFcfaSnapshot, unitPriceFcfaSnapshot) ||
                other.unitPriceFcfaSnapshot == unitPriceFcfaSnapshot) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.variantId, variantId) ||
                other.variantId == variantId) &&
            (identical(other.variantNameSnapshot, variantNameSnapshot) ||
                other.variantNameSnapshot == variantNameSnapshot));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    productNameSnapshot,
    unitPriceFcfaSnapshot,
    quantity,
    variantId,
    variantNameSnapshot,
  );

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      __$$OrderItemImplCopyWithImpl<_$OrderItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderItemImplToJson(this);
  }
}

abstract class _OrderItem implements OrderItem {
  const factory _OrderItem({
    required final String productId,
    required final String productNameSnapshot,
    required final int unitPriceFcfaSnapshot,
    required final int quantity,
    final String? variantId,
    final String? variantNameSnapshot,
  }) = _$OrderItemImpl;

  factory _OrderItem.fromJson(Map<String, dynamic> json) =
      _$OrderItemImpl.fromJson;

  @override
  String get productId;
  @override
  String get productNameSnapshot;
  @override
  int get unitPriceFcfaSnapshot;
  @override
  int get quantity;

  /// Which variant was ordered, if the product had variants at order
  /// time — `null` for a variant-less product.
  @override
  String? get variantId;
  @override
  String? get variantNameSnapshot;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderSupplierGroup _$OrderSupplierGroupFromJson(Map<String, dynamic> json) {
  return _OrderSupplierGroup.fromJson(json);
}

/// @nodoc
mixin _$OrderSupplierGroup {
  String get id => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  String get supplierName => throw _privateConstructorUsedError;
  List<OrderItem> get items => throw _privateConstructorUsedError;
  DeliveryMode get deliveryMode => throw _privateConstructorUsedError;
  int get deliveryFeeFcfa => throw _privateConstructorUsedError;
  int get subtotalFcfa => throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;

  /// Only set when [status] is `cancelled` — shown back to the client so
  /// a refusal isn't a silent dead end.
  String? get cancellationReason => throw _privateConstructorUsedError;
  CancelledBy? get cancelledBy => throw _privateConstructorUsedError;

  /// Serializes this OrderSupplierGroup to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderSupplierGroupCopyWith<OrderSupplierGroup> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderSupplierGroupCopyWith<$Res> {
  factory $OrderSupplierGroupCopyWith(
    OrderSupplierGroup value,
    $Res Function(OrderSupplierGroup) then,
  ) = _$OrderSupplierGroupCopyWithImpl<$Res, OrderSupplierGroup>;
  @useResult
  $Res call({
    String id,
    String supplierId,
    String supplierName,
    List<OrderItem> items,
    DeliveryMode deliveryMode,
    int deliveryFeeFcfa,
    int subtotalFcfa,
    OrderStatus status,
    String? cancellationReason,
    CancelledBy? cancelledBy,
  });
}

/// @nodoc
class _$OrderSupplierGroupCopyWithImpl<$Res, $Val extends OrderSupplierGroup>
    implements $OrderSupplierGroupCopyWith<$Res> {
  _$OrderSupplierGroupCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? items = null,
    Object? deliveryMode = null,
    Object? deliveryFeeFcfa = null,
    Object? subtotalFcfa = null,
    Object? status = null,
    Object? cancellationReason = freezed,
    Object? cancelledBy = freezed,
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
            supplierName: null == supplierName
                ? _value.supplierName
                : supplierName // ignore: cast_nullable_to_non_nullable
                      as String,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<OrderItem>,
            deliveryMode: null == deliveryMode
                ? _value.deliveryMode
                : deliveryMode // ignore: cast_nullable_to_non_nullable
                      as DeliveryMode,
            deliveryFeeFcfa: null == deliveryFeeFcfa
                ? _value.deliveryFeeFcfa
                : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            subtotalFcfa: null == subtotalFcfa
                ? _value.subtotalFcfa
                : subtotalFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OrderStatus,
            cancellationReason: freezed == cancellationReason
                ? _value.cancellationReason
                : cancellationReason // ignore: cast_nullable_to_non_nullable
                      as String?,
            cancelledBy: freezed == cancelledBy
                ? _value.cancelledBy
                : cancelledBy // ignore: cast_nullable_to_non_nullable
                      as CancelledBy?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderSupplierGroupImplCopyWith<$Res>
    implements $OrderSupplierGroupCopyWith<$Res> {
  factory _$$OrderSupplierGroupImplCopyWith(
    _$OrderSupplierGroupImpl value,
    $Res Function(_$OrderSupplierGroupImpl) then,
  ) = __$$OrderSupplierGroupImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String supplierId,
    String supplierName,
    List<OrderItem> items,
    DeliveryMode deliveryMode,
    int deliveryFeeFcfa,
    int subtotalFcfa,
    OrderStatus status,
    String? cancellationReason,
    CancelledBy? cancelledBy,
  });
}

/// @nodoc
class __$$OrderSupplierGroupImplCopyWithImpl<$Res>
    extends _$OrderSupplierGroupCopyWithImpl<$Res, _$OrderSupplierGroupImpl>
    implements _$$OrderSupplierGroupImplCopyWith<$Res> {
  __$$OrderSupplierGroupImplCopyWithImpl(
    _$OrderSupplierGroupImpl _value,
    $Res Function(_$OrderSupplierGroupImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? items = null,
    Object? deliveryMode = null,
    Object? deliveryFeeFcfa = null,
    Object? subtotalFcfa = null,
    Object? status = null,
    Object? cancellationReason = freezed,
    Object? cancelledBy = freezed,
  }) {
    return _then(
      _$OrderSupplierGroupImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierName: null == supplierName
            ? _value.supplierName
            : supplierName // ignore: cast_nullable_to_non_nullable
                  as String,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<OrderItem>,
        deliveryMode: null == deliveryMode
            ? _value.deliveryMode
            : deliveryMode // ignore: cast_nullable_to_non_nullable
                  as DeliveryMode,
        deliveryFeeFcfa: null == deliveryFeeFcfa
            ? _value.deliveryFeeFcfa
            : deliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        subtotalFcfa: null == subtotalFcfa
            ? _value.subtotalFcfa
            : subtotalFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OrderStatus,
        cancellationReason: freezed == cancellationReason
            ? _value.cancellationReason
            : cancellationReason // ignore: cast_nullable_to_non_nullable
                  as String?,
        cancelledBy: freezed == cancelledBy
            ? _value.cancelledBy
            : cancelledBy // ignore: cast_nullable_to_non_nullable
                  as CancelledBy?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderSupplierGroupImpl implements _OrderSupplierGroup {
  const _$OrderSupplierGroupImpl({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required final List<OrderItem> items,
    required this.deliveryMode,
    required this.deliveryFeeFcfa,
    required this.subtotalFcfa,
    required this.status,
    this.cancellationReason,
    this.cancelledBy,
  }) : _items = items;

  factory _$OrderSupplierGroupImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderSupplierGroupImplFromJson(json);

  @override
  final String id;
  @override
  final String supplierId;
  @override
  final String supplierName;
  final List<OrderItem> _items;
  @override
  List<OrderItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final DeliveryMode deliveryMode;
  @override
  final int deliveryFeeFcfa;
  @override
  final int subtotalFcfa;
  @override
  final OrderStatus status;

  /// Only set when [status] is `cancelled` — shown back to the client so
  /// a refusal isn't a silent dead end.
  @override
  final String? cancellationReason;
  @override
  final CancelledBy? cancelledBy;

  @override
  String toString() {
    return 'OrderSupplierGroup(id: $id, supplierId: $supplierId, supplierName: $supplierName, items: $items, deliveryMode: $deliveryMode, deliveryFeeFcfa: $deliveryFeeFcfa, subtotalFcfa: $subtotalFcfa, status: $status, cancellationReason: $cancellationReason, cancelledBy: $cancelledBy)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderSupplierGroupImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.supplierName, supplierName) ||
                other.supplierName == supplierName) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.deliveryMode, deliveryMode) ||
                other.deliveryMode == deliveryMode) &&
            (identical(other.deliveryFeeFcfa, deliveryFeeFcfa) ||
                other.deliveryFeeFcfa == deliveryFeeFcfa) &&
            (identical(other.subtotalFcfa, subtotalFcfa) ||
                other.subtotalFcfa == subtotalFcfa) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.cancellationReason, cancellationReason) ||
                other.cancellationReason == cancellationReason) &&
            (identical(other.cancelledBy, cancelledBy) ||
                other.cancelledBy == cancelledBy));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    supplierId,
    supplierName,
    const DeepCollectionEquality().hash(_items),
    deliveryMode,
    deliveryFeeFcfa,
    subtotalFcfa,
    status,
    cancellationReason,
    cancelledBy,
  );

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderSupplierGroupImplCopyWith<_$OrderSupplierGroupImpl> get copyWith =>
      __$$OrderSupplierGroupImplCopyWithImpl<_$OrderSupplierGroupImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderSupplierGroupImplToJson(this);
  }
}

abstract class _OrderSupplierGroup implements OrderSupplierGroup {
  const factory _OrderSupplierGroup({
    required final String id,
    required final String supplierId,
    required final String supplierName,
    required final List<OrderItem> items,
    required final DeliveryMode deliveryMode,
    required final int deliveryFeeFcfa,
    required final int subtotalFcfa,
    required final OrderStatus status,
    final String? cancellationReason,
    final CancelledBy? cancelledBy,
  }) = _$OrderSupplierGroupImpl;

  factory _OrderSupplierGroup.fromJson(Map<String, dynamic> json) =
      _$OrderSupplierGroupImpl.fromJson;

  @override
  String get id;
  @override
  String get supplierId;
  @override
  String get supplierName;
  @override
  List<OrderItem> get items;
  @override
  DeliveryMode get deliveryMode;
  @override
  int get deliveryFeeFcfa;
  @override
  int get subtotalFcfa;
  @override
  OrderStatus get status;

  /// Only set when [status] is `cancelled` — shown back to the client so
  /// a refusal isn't a silent dead end.
  @override
  String? get cancellationReason;
  @override
  CancelledBy? get cancelledBy;

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderSupplierGroupImplCopyWith<_$OrderSupplierGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

OrderContact _$OrderContactFromJson(Map<String, dynamic> json) {
  return _OrderContact.fromJson(json);
}

/// @nodoc
mixin _$OrderContact {
  /// Le numéro à appeler pour la livraison : celui donné au paiement,
  /// sinon celui du compte.
  String? get phone => throw _privateConstructorUsedError;
  String? get alternatePhone => throw _privateConstructorUsedError;

  /// Le nom de l'adresse (« Maison »), ou celui du point relais.
  String? get addressLabel => throw _privateConstructorUsedError;
  String? get addressDetails => throw _privateConstructorUsedError;
  double? get latitude => throw _privateConstructorUsedError;
  double? get longitude => throw _privateConstructorUsedError;

  /// Serializes this OrderContact to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of OrderContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderContactCopyWith<OrderContact> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderContactCopyWith<$Res> {
  factory $OrderContactCopyWith(
    OrderContact value,
    $Res Function(OrderContact) then,
  ) = _$OrderContactCopyWithImpl<$Res, OrderContact>;
  @useResult
  $Res call({
    String? phone,
    String? alternatePhone,
    String? addressLabel,
    String? addressDetails,
    double? latitude,
    double? longitude,
  });
}

/// @nodoc
class _$OrderContactCopyWithImpl<$Res, $Val extends OrderContact>
    implements $OrderContactCopyWith<$Res> {
  _$OrderContactCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of OrderContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phone = freezed,
    Object? alternatePhone = freezed,
    Object? addressLabel = freezed,
    Object? addressDetails = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
  }) {
    return _then(
      _value.copyWith(
            phone: freezed == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String?,
            alternatePhone: freezed == alternatePhone
                ? _value.alternatePhone
                : alternatePhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            addressLabel: freezed == addressLabel
                ? _value.addressLabel
                : addressLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            addressDetails: freezed == addressDetails
                ? _value.addressDetails
                : addressDetails // ignore: cast_nullable_to_non_nullable
                      as String?,
            latitude: freezed == latitude
                ? _value.latitude
                : latitude // ignore: cast_nullable_to_non_nullable
                      as double?,
            longitude: freezed == longitude
                ? _value.longitude
                : longitude // ignore: cast_nullable_to_non_nullable
                      as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$OrderContactImplCopyWith<$Res>
    implements $OrderContactCopyWith<$Res> {
  factory _$$OrderContactImplCopyWith(
    _$OrderContactImpl value,
    $Res Function(_$OrderContactImpl) then,
  ) = __$$OrderContactImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? phone,
    String? alternatePhone,
    String? addressLabel,
    String? addressDetails,
    double? latitude,
    double? longitude,
  });
}

/// @nodoc
class __$$OrderContactImplCopyWithImpl<$Res>
    extends _$OrderContactCopyWithImpl<$Res, _$OrderContactImpl>
    implements _$$OrderContactImplCopyWith<$Res> {
  __$$OrderContactImplCopyWithImpl(
    _$OrderContactImpl _value,
    $Res Function(_$OrderContactImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of OrderContact
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? phone = freezed,
    Object? alternatePhone = freezed,
    Object? addressLabel = freezed,
    Object? addressDetails = freezed,
    Object? latitude = freezed,
    Object? longitude = freezed,
  }) {
    return _then(
      _$OrderContactImpl(
        phone: freezed == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String?,
        alternatePhone: freezed == alternatePhone
            ? _value.alternatePhone
            : alternatePhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        addressLabel: freezed == addressLabel
            ? _value.addressLabel
            : addressLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        addressDetails: freezed == addressDetails
            ? _value.addressDetails
            : addressDetails // ignore: cast_nullable_to_non_nullable
                  as String?,
        latitude: freezed == latitude
            ? _value.latitude
            : latitude // ignore: cast_nullable_to_non_nullable
                  as double?,
        longitude: freezed == longitude
            ? _value.longitude
            : longitude // ignore: cast_nullable_to_non_nullable
                  as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderContactImpl extends _OrderContact {
  const _$OrderContactImpl({
    this.phone,
    this.alternatePhone,
    this.addressLabel,
    this.addressDetails,
    this.latitude,
    this.longitude,
  }) : super._();

  factory _$OrderContactImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderContactImplFromJson(json);

  /// Le numéro à appeler pour la livraison : celui donné au paiement,
  /// sinon celui du compte.
  @override
  final String? phone;
  @override
  final String? alternatePhone;

  /// Le nom de l'adresse (« Maison »), ou celui du point relais.
  @override
  final String? addressLabel;
  @override
  final String? addressDetails;
  @override
  final double? latitude;
  @override
  final double? longitude;

  @override
  String toString() {
    return 'OrderContact(phone: $phone, alternatePhone: $alternatePhone, addressLabel: $addressLabel, addressDetails: $addressDetails, latitude: $latitude, longitude: $longitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderContactImpl &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.alternatePhone, alternatePhone) ||
                other.alternatePhone == alternatePhone) &&
            (identical(other.addressLabel, addressLabel) ||
                other.addressLabel == addressLabel) &&
            (identical(other.addressDetails, addressDetails) ||
                other.addressDetails == addressDetails) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    phone,
    alternatePhone,
    addressLabel,
    addressDetails,
    latitude,
    longitude,
  );

  /// Create a copy of OrderContact
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderContactImplCopyWith<_$OrderContactImpl> get copyWith =>
      __$$OrderContactImplCopyWithImpl<_$OrderContactImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderContactImplToJson(this);
  }
}

abstract class _OrderContact extends OrderContact {
  const factory _OrderContact({
    final String? phone,
    final String? alternatePhone,
    final String? addressLabel,
    final String? addressDetails,
    final double? latitude,
    final double? longitude,
  }) = _$OrderContactImpl;
  const _OrderContact._() : super._();

  factory _OrderContact.fromJson(Map<String, dynamic> json) =
      _$OrderContactImpl.fromJson;

  /// Le numéro à appeler pour la livraison : celui donné au paiement,
  /// sinon celui du compte.
  @override
  String? get phone;
  @override
  String? get alternatePhone;

  /// Le nom de l'adresse (« Maison »), ou celui du point relais.
  @override
  String? get addressLabel;
  @override
  String? get addressDetails;
  @override
  double? get latitude;
  @override
  double? get longitude;

  /// Create a copy of OrderContact
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderContactImplCopyWith<_$OrderContactImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Order _$OrderFromJson(Map<String, dynamic> json) {
  return _Order.fromJson(json);
}

/// @nodoc
mixin _$Order {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify the client without a
  /// live join back to their (client-only-readable) profile.
  String get clientDisplayNameSnapshot => throw _privateConstructorUsedError;
  List<OrderSupplierGroup> get supplierGroups =>
      throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;
  DateTime get placedAt => throw _privateConstructorUsedError;
  int get totalFcfa => throw _privateConstructorUsedError;

  /// La ville seule : elle ne désigne personne, et reste donc visible de
  /// tous ceux qui voient la commande.
  String get deliveryCity => throw _privateConstructorUsedError;

  /// Numéros et adresse — `null` quand l'appelant n'a plus droit à rien
  /// (une boutique dont la part est livrée, par exemple).
  OrderContact? get clientContact => throw _privateConstructorUsedError;

  /// Where the client receives the order — home address or a pickup point
  /// (whose own name/address then fill [clientContact]). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  FulfillmentMethod get fulfillmentMethod => throw _privateConstructorUsedError;
  DateTime? get deliveryDate => throw _privateConstructorUsedError;
  String? get deliveryTimeSlotLabel => throw _privateConstructorUsedError;
  bool get isPriority => throw _privateConstructorUsedError;
  int get priorityFeeFcfa => throw _privateConstructorUsedError;

  /// The client's note to the supplier — text or voice, see
  /// [SupplierMessageType]. Only set for [FulfillmentMethod.homeDelivery].
  SupplierMessageType get supplierMessageType =>
      throw _privateConstructorUsedError;
  String? get supplierMessageText => throw _privateConstructorUsedError;
  String? get supplierMessageVoicePath => throw _privateConstructorUsedError;
  int? get supplierMessageVoiceDurationSeconds =>
      throw _privateConstructorUsedError;
  PaymentMethod get paymentMethod => throw _privateConstructorUsedError;
  PaymentStatus get paymentStatus => throw _privateConstructorUsedError;
  MobileMoneyProvider? get mobileMoneyProvider =>
      throw _privateConstructorUsedError;

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $OrderCopyWith<Order> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $OrderCopyWith<$Res> {
  factory $OrderCopyWith(Order value, $Res Function(Order) then) =
      _$OrderCopyWithImpl<$Res, Order>;
  @useResult
  $Res call({
    String id,
    String clientId,
    String clientDisplayNameSnapshot,
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryCity,
    OrderContact? clientContact,
    FulfillmentMethod fulfillmentMethod,
    DateTime? deliveryDate,
    String? deliveryTimeSlotLabel,
    bool isPriority,
    int priorityFeeFcfa,
    SupplierMessageType supplierMessageType,
    String? supplierMessageText,
    String? supplierMessageVoicePath,
    int? supplierMessageVoiceDurationSeconds,
    PaymentMethod paymentMethod,
    PaymentStatus paymentStatus,
    MobileMoneyProvider? mobileMoneyProvider,
  });

  $OrderContactCopyWith<$Res>? get clientContact;
}

/// @nodoc
class _$OrderCopyWithImpl<$Res, $Val extends Order>
    implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? clientDisplayNameSnapshot = null,
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryCity = null,
    Object? clientContact = freezed,
    Object? fulfillmentMethod = null,
    Object? deliveryDate = freezed,
    Object? deliveryTimeSlotLabel = freezed,
    Object? isPriority = null,
    Object? priorityFeeFcfa = null,
    Object? supplierMessageType = null,
    Object? supplierMessageText = freezed,
    Object? supplierMessageVoicePath = freezed,
    Object? supplierMessageVoiceDurationSeconds = freezed,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? mobileMoneyProvider = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            clientId: null == clientId
                ? _value.clientId
                : clientId // ignore: cast_nullable_to_non_nullable
                      as String,
            clientDisplayNameSnapshot: null == clientDisplayNameSnapshot
                ? _value.clientDisplayNameSnapshot
                : clientDisplayNameSnapshot // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierGroups: null == supplierGroups
                ? _value.supplierGroups
                : supplierGroups // ignore: cast_nullable_to_non_nullable
                      as List<OrderSupplierGroup>,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as OrderStatus,
            placedAt: null == placedAt
                ? _value.placedAt
                : placedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalFcfa: null == totalFcfa
                ? _value.totalFcfa
                : totalFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            deliveryCity: null == deliveryCity
                ? _value.deliveryCity
                : deliveryCity // ignore: cast_nullable_to_non_nullable
                      as String,
            clientContact: freezed == clientContact
                ? _value.clientContact
                : clientContact // ignore: cast_nullable_to_non_nullable
                      as OrderContact?,
            fulfillmentMethod: null == fulfillmentMethod
                ? _value.fulfillmentMethod
                : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
                      as FulfillmentMethod,
            deliveryDate: freezed == deliveryDate
                ? _value.deliveryDate
                : deliveryDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            deliveryTimeSlotLabel: freezed == deliveryTimeSlotLabel
                ? _value.deliveryTimeSlotLabel
                : deliveryTimeSlotLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
            isPriority: null == isPriority
                ? _value.isPriority
                : isPriority // ignore: cast_nullable_to_non_nullable
                      as bool,
            priorityFeeFcfa: null == priorityFeeFcfa
                ? _value.priorityFeeFcfa
                : priorityFeeFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            supplierMessageType: null == supplierMessageType
                ? _value.supplierMessageType
                : supplierMessageType // ignore: cast_nullable_to_non_nullable
                      as SupplierMessageType,
            supplierMessageText: freezed == supplierMessageText
                ? _value.supplierMessageText
                : supplierMessageText // ignore: cast_nullable_to_non_nullable
                      as String?,
            supplierMessageVoicePath: freezed == supplierMessageVoicePath
                ? _value.supplierMessageVoicePath
                : supplierMessageVoicePath // ignore: cast_nullable_to_non_nullable
                      as String?,
            supplierMessageVoiceDurationSeconds:
                freezed == supplierMessageVoiceDurationSeconds
                ? _value.supplierMessageVoiceDurationSeconds
                : supplierMessageVoiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                      as int?,
            paymentMethod: null == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as PaymentMethod,
            paymentStatus: null == paymentStatus
                ? _value.paymentStatus
                : paymentStatus // ignore: cast_nullable_to_non_nullable
                      as PaymentStatus,
            mobileMoneyProvider: freezed == mobileMoneyProvider
                ? _value.mobileMoneyProvider
                : mobileMoneyProvider // ignore: cast_nullable_to_non_nullable
                      as MobileMoneyProvider?,
          )
          as $Val,
    );
  }

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrderContactCopyWith<$Res>? get clientContact {
    if (_value.clientContact == null) {
      return null;
    }

    return $OrderContactCopyWith<$Res>(_value.clientContact!, (value) {
      return _then(_value.copyWith(clientContact: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$OrderImplCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$$OrderImplCopyWith(
    _$OrderImpl value,
    $Res Function(_$OrderImpl) then,
  ) = __$$OrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String clientId,
    String clientDisplayNameSnapshot,
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryCity,
    OrderContact? clientContact,
    FulfillmentMethod fulfillmentMethod,
    DateTime? deliveryDate,
    String? deliveryTimeSlotLabel,
    bool isPriority,
    int priorityFeeFcfa,
    SupplierMessageType supplierMessageType,
    String? supplierMessageText,
    String? supplierMessageVoicePath,
    int? supplierMessageVoiceDurationSeconds,
    PaymentMethod paymentMethod,
    PaymentStatus paymentStatus,
    MobileMoneyProvider? mobileMoneyProvider,
  });

  @override
  $OrderContactCopyWith<$Res>? get clientContact;
}

/// @nodoc
class __$$OrderImplCopyWithImpl<$Res>
    extends _$OrderCopyWithImpl<$Res, _$OrderImpl>
    implements _$$OrderImplCopyWith<$Res> {
  __$$OrderImplCopyWithImpl(
    _$OrderImpl _value,
    $Res Function(_$OrderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? clientId = null,
    Object? clientDisplayNameSnapshot = null,
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryCity = null,
    Object? clientContact = freezed,
    Object? fulfillmentMethod = null,
    Object? deliveryDate = freezed,
    Object? deliveryTimeSlotLabel = freezed,
    Object? isPriority = null,
    Object? priorityFeeFcfa = null,
    Object? supplierMessageType = null,
    Object? supplierMessageText = freezed,
    Object? supplierMessageVoicePath = freezed,
    Object? supplierMessageVoiceDurationSeconds = freezed,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? mobileMoneyProvider = freezed,
  }) {
    return _then(
      _$OrderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        clientId: null == clientId
            ? _value.clientId
            : clientId // ignore: cast_nullable_to_non_nullable
                  as String,
        clientDisplayNameSnapshot: null == clientDisplayNameSnapshot
            ? _value.clientDisplayNameSnapshot
            : clientDisplayNameSnapshot // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierGroups: null == supplierGroups
            ? _value._supplierGroups
            : supplierGroups // ignore: cast_nullable_to_non_nullable
                  as List<OrderSupplierGroup>,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as OrderStatus,
        placedAt: null == placedAt
            ? _value.placedAt
            : placedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalFcfa: null == totalFcfa
            ? _value.totalFcfa
            : totalFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        deliveryCity: null == deliveryCity
            ? _value.deliveryCity
            : deliveryCity // ignore: cast_nullable_to_non_nullable
                  as String,
        clientContact: freezed == clientContact
            ? _value.clientContact
            : clientContact // ignore: cast_nullable_to_non_nullable
                  as OrderContact?,
        fulfillmentMethod: null == fulfillmentMethod
            ? _value.fulfillmentMethod
            : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
                  as FulfillmentMethod,
        deliveryDate: freezed == deliveryDate
            ? _value.deliveryDate
            : deliveryDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        deliveryTimeSlotLabel: freezed == deliveryTimeSlotLabel
            ? _value.deliveryTimeSlotLabel
            : deliveryTimeSlotLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
        isPriority: null == isPriority
            ? _value.isPriority
            : isPriority // ignore: cast_nullable_to_non_nullable
                  as bool,
        priorityFeeFcfa: null == priorityFeeFcfa
            ? _value.priorityFeeFcfa
            : priorityFeeFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        supplierMessageType: null == supplierMessageType
            ? _value.supplierMessageType
            : supplierMessageType // ignore: cast_nullable_to_non_nullable
                  as SupplierMessageType,
        supplierMessageText: freezed == supplierMessageText
            ? _value.supplierMessageText
            : supplierMessageText // ignore: cast_nullable_to_non_nullable
                  as String?,
        supplierMessageVoicePath: freezed == supplierMessageVoicePath
            ? _value.supplierMessageVoicePath
            : supplierMessageVoicePath // ignore: cast_nullable_to_non_nullable
                  as String?,
        supplierMessageVoiceDurationSeconds:
            freezed == supplierMessageVoiceDurationSeconds
            ? _value.supplierMessageVoiceDurationSeconds
            : supplierMessageVoiceDurationSeconds // ignore: cast_nullable_to_non_nullable
                  as int?,
        paymentMethod: null == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as PaymentMethod,
        paymentStatus: null == paymentStatus
            ? _value.paymentStatus
            : paymentStatus // ignore: cast_nullable_to_non_nullable
                  as PaymentStatus,
        mobileMoneyProvider: freezed == mobileMoneyProvider
            ? _value.mobileMoneyProvider
            : mobileMoneyProvider // ignore: cast_nullable_to_non_nullable
                  as MobileMoneyProvider?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$OrderImpl implements _Order {
  const _$OrderImpl({
    required this.id,
    required this.clientId,
    required this.clientDisplayNameSnapshot,
    required final List<OrderSupplierGroup> supplierGroups,
    required this.status,
    required this.placedAt,
    required this.totalFcfa,
    required this.deliveryCity,
    this.clientContact,
    this.fulfillmentMethod = FulfillmentMethod.homeDelivery,
    this.deliveryDate,
    this.deliveryTimeSlotLabel,
    this.isPriority = false,
    this.priorityFeeFcfa = 0,
    this.supplierMessageType = SupplierMessageType.none,
    this.supplierMessageText,
    this.supplierMessageVoicePath,
    this.supplierMessageVoiceDurationSeconds,
    this.paymentMethod = PaymentMethod.onDelivery,
    this.paymentStatus = PaymentStatus.pendingOnDelivery,
    this.mobileMoneyProvider,
  }) : _supplierGroups = supplierGroups;

  factory _$OrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$OrderImplFromJson(json);

  @override
  final String id;
  @override
  final String clientId;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify the client without a
  /// live join back to their (client-only-readable) profile.
  @override
  final String clientDisplayNameSnapshot;
  final List<OrderSupplierGroup> _supplierGroups;
  @override
  List<OrderSupplierGroup> get supplierGroups {
    if (_supplierGroups is EqualUnmodifiableListView) return _supplierGroups;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supplierGroups);
  }

  @override
  final OrderStatus status;
  @override
  final DateTime placedAt;
  @override
  final int totalFcfa;

  /// La ville seule : elle ne désigne personne, et reste donc visible de
  /// tous ceux qui voient la commande.
  @override
  final String deliveryCity;

  /// Numéros et adresse — `null` quand l'appelant n'a plus droit à rien
  /// (une boutique dont la part est livrée, par exemple).
  @override
  final OrderContact? clientContact;

  /// Where the client receives the order — home address or a pickup point
  /// (whose own name/address then fill [clientContact]). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  @override
  @JsonKey()
  final FulfillmentMethod fulfillmentMethod;
  @override
  final DateTime? deliveryDate;
  @override
  final String? deliveryTimeSlotLabel;
  @override
  @JsonKey()
  final bool isPriority;
  @override
  @JsonKey()
  final int priorityFeeFcfa;

  /// The client's note to the supplier — text or voice, see
  /// [SupplierMessageType]. Only set for [FulfillmentMethod.homeDelivery].
  @override
  @JsonKey()
  final SupplierMessageType supplierMessageType;
  @override
  final String? supplierMessageText;
  @override
  final String? supplierMessageVoicePath;
  @override
  final int? supplierMessageVoiceDurationSeconds;
  @override
  @JsonKey()
  final PaymentMethod paymentMethod;
  @override
  @JsonKey()
  final PaymentStatus paymentStatus;
  @override
  final MobileMoneyProvider? mobileMoneyProvider;

  @override
  String toString() {
    return 'Order(id: $id, clientId: $clientId, clientDisplayNameSnapshot: $clientDisplayNameSnapshot, supplierGroups: $supplierGroups, status: $status, placedAt: $placedAt, totalFcfa: $totalFcfa, deliveryCity: $deliveryCity, clientContact: $clientContact, fulfillmentMethod: $fulfillmentMethod, deliveryDate: $deliveryDate, deliveryTimeSlotLabel: $deliveryTimeSlotLabel, isPriority: $isPriority, priorityFeeFcfa: $priorityFeeFcfa, supplierMessageType: $supplierMessageType, supplierMessageText: $supplierMessageText, supplierMessageVoicePath: $supplierMessageVoicePath, supplierMessageVoiceDurationSeconds: $supplierMessageVoiceDurationSeconds, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, mobileMoneyProvider: $mobileMoneyProvider)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            (identical(
                  other.clientDisplayNameSnapshot,
                  clientDisplayNameSnapshot,
                ) ||
                other.clientDisplayNameSnapshot == clientDisplayNameSnapshot) &&
            const DeepCollectionEquality().equals(
              other._supplierGroups,
              _supplierGroups,
            ) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.placedAt, placedAt) ||
                other.placedAt == placedAt) &&
            (identical(other.totalFcfa, totalFcfa) ||
                other.totalFcfa == totalFcfa) &&
            (identical(other.deliveryCity, deliveryCity) ||
                other.deliveryCity == deliveryCity) &&
            (identical(other.clientContact, clientContact) ||
                other.clientContact == clientContact) &&
            (identical(other.fulfillmentMethod, fulfillmentMethod) ||
                other.fulfillmentMethod == fulfillmentMethod) &&
            (identical(other.deliveryDate, deliveryDate) ||
                other.deliveryDate == deliveryDate) &&
            (identical(other.deliveryTimeSlotLabel, deliveryTimeSlotLabel) ||
                other.deliveryTimeSlotLabel == deliveryTimeSlotLabel) &&
            (identical(other.isPriority, isPriority) ||
                other.isPriority == isPriority) &&
            (identical(other.priorityFeeFcfa, priorityFeeFcfa) ||
                other.priorityFeeFcfa == priorityFeeFcfa) &&
            (identical(other.supplierMessageType, supplierMessageType) ||
                other.supplierMessageType == supplierMessageType) &&
            (identical(other.supplierMessageText, supplierMessageText) ||
                other.supplierMessageText == supplierMessageText) &&
            (identical(
                  other.supplierMessageVoicePath,
                  supplierMessageVoicePath,
                ) ||
                other.supplierMessageVoicePath == supplierMessageVoicePath) &&
            (identical(
                  other.supplierMessageVoiceDurationSeconds,
                  supplierMessageVoiceDurationSeconds,
                ) ||
                other.supplierMessageVoiceDurationSeconds ==
                    supplierMessageVoiceDurationSeconds) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.mobileMoneyProvider, mobileMoneyProvider) ||
                other.mobileMoneyProvider == mobileMoneyProvider));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    clientId,
    clientDisplayNameSnapshot,
    const DeepCollectionEquality().hash(_supplierGroups),
    status,
    placedAt,
    totalFcfa,
    deliveryCity,
    clientContact,
    fulfillmentMethod,
    deliveryDate,
    deliveryTimeSlotLabel,
    isPriority,
    priorityFeeFcfa,
    supplierMessageType,
    supplierMessageText,
    supplierMessageVoicePath,
    supplierMessageVoiceDurationSeconds,
    paymentMethod,
    paymentStatus,
    mobileMoneyProvider,
  ]);

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      __$$OrderImplCopyWithImpl<_$OrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$OrderImplToJson(this);
  }
}

abstract class _Order implements Order {
  const factory _Order({
    required final String id,
    required final String clientId,
    required final String clientDisplayNameSnapshot,
    required final List<OrderSupplierGroup> supplierGroups,
    required final OrderStatus status,
    required final DateTime placedAt,
    required final int totalFcfa,
    required final String deliveryCity,
    final OrderContact? clientContact,
    final FulfillmentMethod fulfillmentMethod,
    final DateTime? deliveryDate,
    final String? deliveryTimeSlotLabel,
    final bool isPriority,
    final int priorityFeeFcfa,
    final SupplierMessageType supplierMessageType,
    final String? supplierMessageText,
    final String? supplierMessageVoicePath,
    final int? supplierMessageVoiceDurationSeconds,
    final PaymentMethod paymentMethod,
    final PaymentStatus paymentStatus,
    final MobileMoneyProvider? mobileMoneyProvider,
  }) = _$OrderImpl;

  factory _Order.fromJson(Map<String, dynamic> json) = _$OrderImpl.fromJson;

  @override
  String get id;
  @override
  String get clientId;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify the client without a
  /// live join back to their (client-only-readable) profile.
  @override
  String get clientDisplayNameSnapshot;
  @override
  List<OrderSupplierGroup> get supplierGroups;
  @override
  OrderStatus get status;
  @override
  DateTime get placedAt;
  @override
  int get totalFcfa;

  /// La ville seule : elle ne désigne personne, et reste donc visible de
  /// tous ceux qui voient la commande.
  @override
  String get deliveryCity;

  /// Numéros et adresse — `null` quand l'appelant n'a plus droit à rien
  /// (une boutique dont la part est livrée, par exemple).
  @override
  OrderContact? get clientContact;

  /// Where the client receives the order — home address or a pickup point
  /// (whose own name/address then fill [clientContact]). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  @override
  FulfillmentMethod get fulfillmentMethod;
  @override
  DateTime? get deliveryDate;
  @override
  String? get deliveryTimeSlotLabel;
  @override
  bool get isPriority;
  @override
  int get priorityFeeFcfa;

  /// The client's note to the supplier — text or voice, see
  /// [SupplierMessageType]. Only set for [FulfillmentMethod.homeDelivery].
  @override
  SupplierMessageType get supplierMessageType;
  @override
  String? get supplierMessageText;
  @override
  String? get supplierMessageVoicePath;
  @override
  int? get supplierMessageVoiceDurationSeconds;
  @override
  PaymentMethod get paymentMethod;
  @override
  PaymentStatus get paymentStatus;
  @override
  MobileMoneyProvider? get mobileMoneyProvider;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$CheckoutGroupInput {
  String get supplierId => throw _privateConstructorUsedError;
  String get supplierName => throw _privateConstructorUsedError;
  List<OrderItem> get items => throw _privateConstructorUsedError;
  DeliveryMode get deliveryMode => throw _privateConstructorUsedError;
  int get mtcDeliveryFeeFcfa => throw _privateConstructorUsedError;

  /// Create a copy of CheckoutGroupInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CheckoutGroupInputCopyWith<CheckoutGroupInput> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CheckoutGroupInputCopyWith<$Res> {
  factory $CheckoutGroupInputCopyWith(
    CheckoutGroupInput value,
    $Res Function(CheckoutGroupInput) then,
  ) = _$CheckoutGroupInputCopyWithImpl<$Res, CheckoutGroupInput>;
  @useResult
  $Res call({
    String supplierId,
    String supplierName,
    List<OrderItem> items,
    DeliveryMode deliveryMode,
    int mtcDeliveryFeeFcfa,
  });
}

/// @nodoc
class _$CheckoutGroupInputCopyWithImpl<$Res, $Val extends CheckoutGroupInput>
    implements $CheckoutGroupInputCopyWith<$Res> {
  _$CheckoutGroupInputCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CheckoutGroupInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supplierId = null,
    Object? supplierName = null,
    Object? items = null,
    Object? deliveryMode = null,
    Object? mtcDeliveryFeeFcfa = null,
  }) {
    return _then(
      _value.copyWith(
            supplierId: null == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String,
            supplierName: null == supplierName
                ? _value.supplierName
                : supplierName // ignore: cast_nullable_to_non_nullable
                      as String,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<OrderItem>,
            deliveryMode: null == deliveryMode
                ? _value.deliveryMode
                : deliveryMode // ignore: cast_nullable_to_non_nullable
                      as DeliveryMode,
            mtcDeliveryFeeFcfa: null == mtcDeliveryFeeFcfa
                ? _value.mtcDeliveryFeeFcfa
                : mtcDeliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CheckoutGroupInputImplCopyWith<$Res>
    implements $CheckoutGroupInputCopyWith<$Res> {
  factory _$$CheckoutGroupInputImplCopyWith(
    _$CheckoutGroupInputImpl value,
    $Res Function(_$CheckoutGroupInputImpl) then,
  ) = __$$CheckoutGroupInputImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String supplierId,
    String supplierName,
    List<OrderItem> items,
    DeliveryMode deliveryMode,
    int mtcDeliveryFeeFcfa,
  });
}

/// @nodoc
class __$$CheckoutGroupInputImplCopyWithImpl<$Res>
    extends _$CheckoutGroupInputCopyWithImpl<$Res, _$CheckoutGroupInputImpl>
    implements _$$CheckoutGroupInputImplCopyWith<$Res> {
  __$$CheckoutGroupInputImplCopyWithImpl(
    _$CheckoutGroupInputImpl _value,
    $Res Function(_$CheckoutGroupInputImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CheckoutGroupInput
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supplierId = null,
    Object? supplierName = null,
    Object? items = null,
    Object? deliveryMode = null,
    Object? mtcDeliveryFeeFcfa = null,
  }) {
    return _then(
      _$CheckoutGroupInputImpl(
        supplierId: null == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String,
        supplierName: null == supplierName
            ? _value.supplierName
            : supplierName // ignore: cast_nullable_to_non_nullable
                  as String,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<OrderItem>,
        deliveryMode: null == deliveryMode
            ? _value.deliveryMode
            : deliveryMode // ignore: cast_nullable_to_non_nullable
                  as DeliveryMode,
        mtcDeliveryFeeFcfa: null == mtcDeliveryFeeFcfa
            ? _value.mtcDeliveryFeeFcfa
            : mtcDeliveryFeeFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$CheckoutGroupInputImpl implements _CheckoutGroupInput {
  const _$CheckoutGroupInputImpl({
    required this.supplierId,
    required this.supplierName,
    required final List<OrderItem> items,
    required this.deliveryMode,
    required this.mtcDeliveryFeeFcfa,
  }) : _items = items;

  @override
  final String supplierId;
  @override
  final String supplierName;
  final List<OrderItem> _items;
  @override
  List<OrderItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final DeliveryMode deliveryMode;
  @override
  final int mtcDeliveryFeeFcfa;

  @override
  String toString() {
    return 'CheckoutGroupInput(supplierId: $supplierId, supplierName: $supplierName, items: $items, deliveryMode: $deliveryMode, mtcDeliveryFeeFcfa: $mtcDeliveryFeeFcfa)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CheckoutGroupInputImpl &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.supplierName, supplierName) ||
                other.supplierName == supplierName) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.deliveryMode, deliveryMode) ||
                other.deliveryMode == deliveryMode) &&
            (identical(other.mtcDeliveryFeeFcfa, mtcDeliveryFeeFcfa) ||
                other.mtcDeliveryFeeFcfa == mtcDeliveryFeeFcfa));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    supplierId,
    supplierName,
    const DeepCollectionEquality().hash(_items),
    deliveryMode,
    mtcDeliveryFeeFcfa,
  );

  /// Create a copy of CheckoutGroupInput
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CheckoutGroupInputImplCopyWith<_$CheckoutGroupInputImpl> get copyWith =>
      __$$CheckoutGroupInputImplCopyWithImpl<_$CheckoutGroupInputImpl>(
        this,
        _$identity,
      );
}

abstract class _CheckoutGroupInput implements CheckoutGroupInput {
  const factory _CheckoutGroupInput({
    required final String supplierId,
    required final String supplierName,
    required final List<OrderItem> items,
    required final DeliveryMode deliveryMode,
    required final int mtcDeliveryFeeFcfa,
  }) = _$CheckoutGroupInputImpl;

  @override
  String get supplierId;
  @override
  String get supplierName;
  @override
  List<OrderItem> get items;
  @override
  DeliveryMode get deliveryMode;
  @override
  int get mtcDeliveryFeeFcfa;

  /// Create a copy of CheckoutGroupInput
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CheckoutGroupInputImplCopyWith<_$CheckoutGroupInputImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
