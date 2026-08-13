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

  /// Only set when [status] is `cancelled` — shown back to the client so
  /// a refusal isn't a silent dead end.
  String? get cancellationReason => throw _privateConstructorUsedError;
  CancelledBy? get cancelledBy => throw _privateConstructorUsedError;

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

/// @nodoc
mixin _$Order {
  String get id => throw _privateConstructorUsedError;
  String get clientId => throw _privateConstructorUsedError;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify/reach the client
  /// without a live join back to their (client-only-readable) profile.
  String get clientDisplayNameSnapshot => throw _privateConstructorUsedError;
  String get clientPhoneSnapshot => throw _privateConstructorUsedError;
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

  /// Where the client receives the order — home address (the fields
  /// above are the client's saved address) or a pickup point (the fields
  /// above are that point's own name/city/address instead). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  FulfillmentMethod get fulfillmentMethod => throw _privateConstructorUsedError;

  /// Only set for [FulfillmentMethod.homeDelivery].
  String? get courierPhone => throw _privateConstructorUsedError;

  /// Optional second contact number, in case the courier can't reach the
  /// client on [courierPhone].
  String? get alternatePhone => throw _privateConstructorUsedError;
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
    String clientPhoneSnapshot,
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
    FulfillmentMethod fulfillmentMethod,
    String? courierPhone,
    String? alternatePhone,
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
    Object? clientPhoneSnapshot = null,
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? fulfillmentMethod = null,
    Object? courierPhone = freezed,
    Object? alternatePhone = freezed,
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
            clientPhoneSnapshot: null == clientPhoneSnapshot
                ? _value.clientPhoneSnapshot
                : clientPhoneSnapshot // ignore: cast_nullable_to_non_nullable
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
            fulfillmentMethod: null == fulfillmentMethod
                ? _value.fulfillmentMethod
                : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
                      as FulfillmentMethod,
            courierPhone: freezed == courierPhone
                ? _value.courierPhone
                : courierPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            alternatePhone: freezed == alternatePhone
                ? _value.alternatePhone
                : alternatePhone // ignore: cast_nullable_to_non_nullable
                      as String?,
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
    String clientPhoneSnapshot,
    List<OrderSupplierGroup> supplierGroups,
    OrderStatus status,
    DateTime placedAt,
    int totalFcfa,
    String deliveryAddressLabel,
    String deliveryCity,
    String deliveryDetails,
    double deliveryLatitude,
    double deliveryLongitude,
    FulfillmentMethod fulfillmentMethod,
    String? courierPhone,
    String? alternatePhone,
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
    Object? clientPhoneSnapshot = null,
    Object? supplierGroups = null,
    Object? status = null,
    Object? placedAt = null,
    Object? totalFcfa = null,
    Object? deliveryAddressLabel = null,
    Object? deliveryCity = null,
    Object? deliveryDetails = null,
    Object? deliveryLatitude = null,
    Object? deliveryLongitude = null,
    Object? fulfillmentMethod = null,
    Object? courierPhone = freezed,
    Object? alternatePhone = freezed,
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
        clientPhoneSnapshot: null == clientPhoneSnapshot
            ? _value.clientPhoneSnapshot
            : clientPhoneSnapshot // ignore: cast_nullable_to_non_nullable
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
        fulfillmentMethod: null == fulfillmentMethod
            ? _value.fulfillmentMethod
            : fulfillmentMethod // ignore: cast_nullable_to_non_nullable
                  as FulfillmentMethod,
        courierPhone: freezed == courierPhone
            ? _value.courierPhone
            : courierPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        alternatePhone: freezed == alternatePhone
            ? _value.alternatePhone
            : alternatePhone // ignore: cast_nullable_to_non_nullable
                  as String?,
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

class _$OrderImpl implements _Order {
  const _$OrderImpl({
    required this.id,
    required this.clientId,
    required this.clientDisplayNameSnapshot,
    required this.clientPhoneSnapshot,
    required final List<OrderSupplierGroup> supplierGroups,
    required this.status,
    required this.placedAt,
    required this.totalFcfa,
    required this.deliveryAddressLabel,
    required this.deliveryCity,
    required this.deliveryDetails,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    this.fulfillmentMethod = FulfillmentMethod.homeDelivery,
    this.courierPhone,
    this.alternatePhone,
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

  @override
  final String id;
  @override
  final String clientId;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify/reach the client
  /// without a live join back to their (client-only-readable) profile.
  @override
  final String clientDisplayNameSnapshot;
  @override
  final String clientPhoneSnapshot;
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

  /// Where the client receives the order — home address (the fields
  /// above are the client's saved address) or a pickup point (the fields
  /// above are that point's own name/city/address instead). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  @override
  @JsonKey()
  final FulfillmentMethod fulfillmentMethod;

  /// Only set for [FulfillmentMethod.homeDelivery].
  @override
  final String? courierPhone;

  /// Optional second contact number, in case the courier can't reach the
  /// client on [courierPhone].
  @override
  final String? alternatePhone;
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
    return 'Order(id: $id, clientId: $clientId, clientDisplayNameSnapshot: $clientDisplayNameSnapshot, clientPhoneSnapshot: $clientPhoneSnapshot, supplierGroups: $supplierGroups, status: $status, placedAt: $placedAt, totalFcfa: $totalFcfa, deliveryAddressLabel: $deliveryAddressLabel, deliveryCity: $deliveryCity, deliveryDetails: $deliveryDetails, deliveryLatitude: $deliveryLatitude, deliveryLongitude: $deliveryLongitude, fulfillmentMethod: $fulfillmentMethod, courierPhone: $courierPhone, alternatePhone: $alternatePhone, deliveryDate: $deliveryDate, deliveryTimeSlotLabel: $deliveryTimeSlotLabel, isPriority: $isPriority, priorityFeeFcfa: $priorityFeeFcfa, supplierMessageType: $supplierMessageType, supplierMessageText: $supplierMessageText, supplierMessageVoicePath: $supplierMessageVoicePath, supplierMessageVoiceDurationSeconds: $supplierMessageVoiceDurationSeconds, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, mobileMoneyProvider: $mobileMoneyProvider)';
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
            (identical(other.clientPhoneSnapshot, clientPhoneSnapshot) ||
                other.clientPhoneSnapshot == clientPhoneSnapshot) &&
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
                other.deliveryLongitude == deliveryLongitude) &&
            (identical(other.fulfillmentMethod, fulfillmentMethod) ||
                other.fulfillmentMethod == fulfillmentMethod) &&
            (identical(other.courierPhone, courierPhone) ||
                other.courierPhone == courierPhone) &&
            (identical(other.alternatePhone, alternatePhone) ||
                other.alternatePhone == alternatePhone) &&
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

  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    clientId,
    clientDisplayNameSnapshot,
    clientPhoneSnapshot,
    const DeepCollectionEquality().hash(_supplierGroups),
    status,
    placedAt,
    totalFcfa,
    deliveryAddressLabel,
    deliveryCity,
    deliveryDetails,
    deliveryLatitude,
    deliveryLongitude,
    fulfillmentMethod,
    courierPhone,
    alternatePhone,
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
}

abstract class _Order implements Order {
  const factory _Order({
    required final String id,
    required final String clientId,
    required final String clientDisplayNameSnapshot,
    required final String clientPhoneSnapshot,
    required final List<OrderSupplierGroup> supplierGroups,
    required final OrderStatus status,
    required final DateTime placedAt,
    required final int totalFcfa,
    required final String deliveryAddressLabel,
    required final String deliveryCity,
    required final String deliveryDetails,
    required final double deliveryLatitude,
    required final double deliveryLongitude,
    final FulfillmentMethod fulfillmentMethod,
    final String? courierPhone,
    final String? alternatePhone,
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

  @override
  String get id;
  @override
  String get clientId;

  /// Denormalized at `placeOrder` time from the client's account, the
  /// same way every other order/cart line snapshots the data it needs —
  /// so a supplier fulfilling the order can identify/reach the client
  /// without a live join back to their (client-only-readable) profile.
  @override
  String get clientDisplayNameSnapshot;
  @override
  String get clientPhoneSnapshot;
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

  /// Where the client receives the order — home address (the fields
  /// above are the client's saved address) or a pickup point (the fields
  /// above are that point's own name/city/address instead). Defaulted so
  /// existing seed orders (all home addresses) don't need updating.
  @override
  FulfillmentMethod get fulfillmentMethod;

  /// Only set for [FulfillmentMethod.homeDelivery].
  @override
  String? get courierPhone;

  /// Optional second contact number, in case the courier can't reach the
  /// client on [courierPhone].
  @override
  String? get alternatePhone;
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
