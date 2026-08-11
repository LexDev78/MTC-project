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

/// @nodoc
mixin _$OrderItem {
  String get productId => throw _privateConstructorUsedError;
  String get productNameSnapshot => throw _privateConstructorUsedError;
  int get unitPriceFcfaSnapshot => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;

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
      ),
    );
  }
}

/// @nodoc

class _$OrderItemImpl implements _OrderItem {
  const _$OrderItemImpl({
    required this.productId,
    required this.productNameSnapshot,
    required this.unitPriceFcfaSnapshot,
    required this.quantity,
  });

  @override
  final String productId;
  @override
  final String productNameSnapshot;
  @override
  final int unitPriceFcfaSnapshot;
  @override
  final int quantity;

  @override
  String toString() {
    return 'OrderItem(productId: $productId, productNameSnapshot: $productNameSnapshot, unitPriceFcfaSnapshot: $unitPriceFcfaSnapshot, quantity: $quantity)';
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
                other.quantity == quantity));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    productNameSnapshot,
    unitPriceFcfaSnapshot,
    quantity,
  );

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      __$$OrderItemImplCopyWithImpl<_$OrderItemImpl>(this, _$identity);
}

abstract class _OrderItem implements OrderItem {
  const factory _OrderItem({
    required final String productId,
    required final String productNameSnapshot,
    required final int unitPriceFcfaSnapshot,
    required final int quantity,
  }) = _$OrderItemImpl;

  @override
  String get productId;
  @override
  String get productNameSnapshot;
  @override
  int get unitPriceFcfaSnapshot;
  @override
  int get quantity;

  /// Create a copy of OrderItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderItemImplCopyWith<_$OrderItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
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
      ),
    );
  }
}

/// @nodoc

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
  }) : _items = items;

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

  @override
  String toString() {
    return 'OrderSupplierGroup(id: $id, supplierId: $supplierId, supplierName: $supplierName, items: $items, deliveryMode: $deliveryMode, deliveryFeeFcfa: $deliveryFeeFcfa, subtotalFcfa: $subtotalFcfa, status: $status)';
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
            (identical(other.status, status) || other.status == status));
  }

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
  }) = _$OrderSupplierGroupImpl;

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

  /// Create a copy of OrderSupplierGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$OrderSupplierGroupImplCopyWith<_$OrderSupplierGroupImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$Order {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;
  List<OrderSupplierGroup> get supplierGroups =>
      throw _privateConstructorUsedError;
  OrderStatus get status => throw _privateConstructorUsedError;
  DateTime get placedAt => throw _privateConstructorUsedError;
  int get totalFcfa => throw _privateConstructorUsedError;
  String get deliveryAddressLabel => throw _privateConstructorUsedError;
  String get deliveryCity => throw _privateConstructorUsedError;
  String get deliveryDetails => throw _privateConstructorUsedError;
  double get deliveryLatitude => throw _privateConstructorUsedError;
  double get deliveryLongitude => throw _privateConstructorUsedError;

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
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
  });
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
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
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
          )
          as $Val,
    );
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
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
  });
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
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
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
      ),
    );
  }
}

/// @nodoc

class _$OrderImpl implements _Order {
  const _$OrderImpl({
    required this.id,
    required this.clientId,
    required final List<OrderSupplierGroup> supplierGroups,
    required this.status,
    required this.placedAt,
    required this.totalFcfa,
    required this.deliveryAddressLabel,
    required this.deliveryCity,
    required this.deliveryDetails,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
  }) : _supplierGroups = supplierGroups;

  @override
  final String id;
  @override
  final String clientId;
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
  @override
  final String deliveryAddressLabel;
  @override
  final String deliveryCity;
  @override
  final String deliveryDetails;
  @override
  final double deliveryLatitude;
  @override
  final double deliveryLongitude;

  @override
  String toString() {
    return 'Order(id: $id, clientId: $clientId, supplierGroups: $supplierGroups, status: $status, placedAt: $placedAt, totalFcfa: $totalFcfa, deliveryAddressLabel: $deliveryAddressLabel, deliveryCity: $deliveryCity, deliveryDetails: $deliveryDetails, deliveryLatitude: $deliveryLatitude, deliveryLongitude: $deliveryLongitude)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$OrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.clientId, clientId) ||
                other.clientId == clientId) &&
            const DeepCollectionEquality().equals(
              other._supplierGroups,
              _supplierGroups,
            ) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.placedAt, placedAt) ||
                other.placedAt == placedAt) &&
            (identical(other.totalFcfa, totalFcfa) ||
                other.totalFcfa == totalFcfa) &&
            (identical(other.deliveryAddressLabel, deliveryAddressLabel) ||
                other.deliveryAddressLabel == deliveryAddressLabel) &&
            (identical(other.deliveryCity, deliveryCity) ||
                other.deliveryCity == deliveryCity) &&
            (identical(other.deliveryDetails, deliveryDetails) ||
                other.deliveryDetails == deliveryDetails) &&
            (identical(other.deliveryLatitude, deliveryLatitude) ||
                other.deliveryLatitude == deliveryLatitude) &&
            (identical(other.deliveryLongitude, deliveryLongitude) ||
                other.deliveryLongitude == deliveryLongitude));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    clientId,
    const DeepCollectionEquality().hash(_supplierGroups),
    status,
    placedAt,
    totalFcfa,
    deliveryAddressLabel,
    deliveryCity,
    deliveryDetails,
    deliveryLatitude,
    deliveryLongitude,
  );

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$OrderImplCopyWith<_$OrderImpl> get copyWith =>
      __$$OrderImplCopyWithImpl<_$OrderImpl>(this, _$identity);
}

abstract class _Order implements Order {
  const factory _Order({
    required final String id,
    required final String clientId,
    required final List<OrderSupplierGroup> supplierGroups,
    required final OrderStatus status,
    required final DateTime placedAt,
    required final int totalFcfa,
    required final String deliveryAddressLabel,
    required final String deliveryCity,
    required final String deliveryDetails,
    required final double deliveryLatitude,
    required final double deliveryLongitude,
  }) = _$OrderImpl;

  @override
  String get id;
  @override
  String get clientId;
  @override
  List<OrderSupplierGroup> get supplierGroups;
  @override
  OrderStatus get status;
  @override
  DateTime get placedAt;
  @override
  int get totalFcfa;
  @override
  String get deliveryAddressLabel;
  @override
  String get deliveryCity;
  @override
  String get deliveryDetails;
  @override
  double get deliveryLatitude;
  @override
  double get deliveryLongitude;

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
