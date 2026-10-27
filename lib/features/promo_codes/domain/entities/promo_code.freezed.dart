// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'promo_code.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$PromoCode {
  String get id => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  int get percent => throw _privateConstructorUsedError;
  bool get isActive => throw _privateConstructorUsedError;
  int get usesCount => throw _privateConstructorUsedError;
  int get maxUsesPerClient => throw _privateConstructorUsedError;
  String? get label => throw _privateConstructorUsedError;
  DateTime? get startsAt => throw _privateConstructorUsedError;
  DateTime? get endsAt => throw _privateConstructorUsedError;

  /// `null` = sans plafond global.
  int? get maxUses => throw _privateConstructorUsedError;
  int? get minOrderFcfa => throw _privateConstructorUsedError;
  List<String> get productIds => throw _privateConstructorUsedError;
  List<PromoCodeRedemption> get redemptions =>
      throw _privateConstructorUsedError;

  /// Create a copy of PromoCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PromoCodeCopyWith<PromoCode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromoCodeCopyWith<$Res> {
  factory $PromoCodeCopyWith(PromoCode value, $Res Function(PromoCode) then) =
      _$PromoCodeCopyWithImpl<$Res, PromoCode>;
  @useResult
  $Res call({
    String id,
    String code,
    int percent,
    bool isActive,
    int usesCount,
    int maxUsesPerClient,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxUses,
    int? minOrderFcfa,
    List<String> productIds,
    List<PromoCodeRedemption> redemptions,
  });
}

/// @nodoc
class _$PromoCodeCopyWithImpl<$Res, $Val extends PromoCode>
    implements $PromoCodeCopyWith<$Res> {
  _$PromoCodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PromoCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? percent = null,
    Object? isActive = null,
    Object? usesCount = null,
    Object? maxUsesPerClient = null,
    Object? label = freezed,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? maxUses = freezed,
    Object? minOrderFcfa = freezed,
    Object? productIds = null,
    Object? redemptions = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            code: null == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String,
            percent: null == percent
                ? _value.percent
                : percent // ignore: cast_nullable_to_non_nullable
                      as int,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            usesCount: null == usesCount
                ? _value.usesCount
                : usesCount // ignore: cast_nullable_to_non_nullable
                      as int,
            maxUsesPerClient: null == maxUsesPerClient
                ? _value.maxUsesPerClient
                : maxUsesPerClient // ignore: cast_nullable_to_non_nullable
                      as int,
            label: freezed == label
                ? _value.label
                : label // ignore: cast_nullable_to_non_nullable
                      as String?,
            startsAt: freezed == startsAt
                ? _value.startsAt
                : startsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endsAt: freezed == endsAt
                ? _value.endsAt
                : endsAt // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            maxUses: freezed == maxUses
                ? _value.maxUses
                : maxUses // ignore: cast_nullable_to_non_nullable
                      as int?,
            minOrderFcfa: freezed == minOrderFcfa
                ? _value.minOrderFcfa
                : minOrderFcfa // ignore: cast_nullable_to_non_nullable
                      as int?,
            productIds: null == productIds
                ? _value.productIds
                : productIds // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            redemptions: null == redemptions
                ? _value.redemptions
                : redemptions // ignore: cast_nullable_to_non_nullable
                      as List<PromoCodeRedemption>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromoCodeImplCopyWith<$Res>
    implements $PromoCodeCopyWith<$Res> {
  factory _$$PromoCodeImplCopyWith(
    _$PromoCodeImpl value,
    $Res Function(_$PromoCodeImpl) then,
  ) = __$$PromoCodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String code,
    int percent,
    bool isActive,
    int usesCount,
    int maxUsesPerClient,
    String? label,
    DateTime? startsAt,
    DateTime? endsAt,
    int? maxUses,
    int? minOrderFcfa,
    List<String> productIds,
    List<PromoCodeRedemption> redemptions,
  });
}

/// @nodoc
class __$$PromoCodeImplCopyWithImpl<$Res>
    extends _$PromoCodeCopyWithImpl<$Res, _$PromoCodeImpl>
    implements _$$PromoCodeImplCopyWith<$Res> {
  __$$PromoCodeImplCopyWithImpl(
    _$PromoCodeImpl _value,
    $Res Function(_$PromoCodeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PromoCode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? percent = null,
    Object? isActive = null,
    Object? usesCount = null,
    Object? maxUsesPerClient = null,
    Object? label = freezed,
    Object? startsAt = freezed,
    Object? endsAt = freezed,
    Object? maxUses = freezed,
    Object? minOrderFcfa = freezed,
    Object? productIds = null,
    Object? redemptions = null,
  }) {
    return _then(
      _$PromoCodeImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        code: null == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String,
        percent: null == percent
            ? _value.percent
            : percent // ignore: cast_nullable_to_non_nullable
                  as int,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        usesCount: null == usesCount
            ? _value.usesCount
            : usesCount // ignore: cast_nullable_to_non_nullable
                  as int,
        maxUsesPerClient: null == maxUsesPerClient
            ? _value.maxUsesPerClient
            : maxUsesPerClient // ignore: cast_nullable_to_non_nullable
                  as int,
        label: freezed == label
            ? _value.label
            : label // ignore: cast_nullable_to_non_nullable
                  as String?,
        startsAt: freezed == startsAt
            ? _value.startsAt
            : startsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endsAt: freezed == endsAt
            ? _value.endsAt
            : endsAt // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        maxUses: freezed == maxUses
            ? _value.maxUses
            : maxUses // ignore: cast_nullable_to_non_nullable
                  as int?,
        minOrderFcfa: freezed == minOrderFcfa
            ? _value.minOrderFcfa
            : minOrderFcfa // ignore: cast_nullable_to_non_nullable
                  as int?,
        productIds: null == productIds
            ? _value._productIds
            : productIds // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        redemptions: null == redemptions
            ? _value._redemptions
            : redemptions // ignore: cast_nullable_to_non_nullable
                  as List<PromoCodeRedemption>,
      ),
    );
  }
}

/// @nodoc

class _$PromoCodeImpl implements _PromoCode {
  const _$PromoCodeImpl({
    required this.id,
    required this.code,
    required this.percent,
    required this.isActive,
    required this.usesCount,
    this.maxUsesPerClient = 1,
    this.label,
    this.startsAt,
    this.endsAt,
    this.maxUses,
    this.minOrderFcfa,
    final List<String> productIds = const [],
    final List<PromoCodeRedemption> redemptions = const [],
  }) : _productIds = productIds,
       _redemptions = redemptions;

  @override
  final String id;
  @override
  final String code;
  @override
  final int percent;
  @override
  final bool isActive;
  @override
  final int usesCount;
  @override
  @JsonKey()
  final int maxUsesPerClient;
  @override
  final String? label;
  @override
  final DateTime? startsAt;
  @override
  final DateTime? endsAt;

  /// `null` = sans plafond global.
  @override
  final int? maxUses;
  @override
  final int? minOrderFcfa;
  final List<String> _productIds;
  @override
  @JsonKey()
  List<String> get productIds {
    if (_productIds is EqualUnmodifiableListView) return _productIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_productIds);
  }

  final List<PromoCodeRedemption> _redemptions;
  @override
  @JsonKey()
  List<PromoCodeRedemption> get redemptions {
    if (_redemptions is EqualUnmodifiableListView) return _redemptions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_redemptions);
  }

  @override
  String toString() {
    return 'PromoCode(id: $id, code: $code, percent: $percent, isActive: $isActive, usesCount: $usesCount, maxUsesPerClient: $maxUsesPerClient, label: $label, startsAt: $startsAt, endsAt: $endsAt, maxUses: $maxUses, minOrderFcfa: $minOrderFcfa, productIds: $productIds, redemptions: $redemptions)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromoCodeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.percent, percent) || other.percent == percent) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.usesCount, usesCount) ||
                other.usesCount == usesCount) &&
            (identical(other.maxUsesPerClient, maxUsesPerClient) ||
                other.maxUsesPerClient == maxUsesPerClient) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.startsAt, startsAt) ||
                other.startsAt == startsAt) &&
            (identical(other.endsAt, endsAt) || other.endsAt == endsAt) &&
            (identical(other.maxUses, maxUses) || other.maxUses == maxUses) &&
            (identical(other.minOrderFcfa, minOrderFcfa) ||
                other.minOrderFcfa == minOrderFcfa) &&
            const DeepCollectionEquality().equals(
              other._productIds,
              _productIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._redemptions,
              _redemptions,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    code,
    percent,
    isActive,
    usesCount,
    maxUsesPerClient,
    label,
    startsAt,
    endsAt,
    maxUses,
    minOrderFcfa,
    const DeepCollectionEquality().hash(_productIds),
    const DeepCollectionEquality().hash(_redemptions),
  );

  /// Create a copy of PromoCode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PromoCodeImplCopyWith<_$PromoCodeImpl> get copyWith =>
      __$$PromoCodeImplCopyWithImpl<_$PromoCodeImpl>(this, _$identity);
}

abstract class _PromoCode implements PromoCode {
  const factory _PromoCode({
    required final String id,
    required final String code,
    required final int percent,
    required final bool isActive,
    required final int usesCount,
    final int maxUsesPerClient,
    final String? label,
    final DateTime? startsAt,
    final DateTime? endsAt,
    final int? maxUses,
    final int? minOrderFcfa,
    final List<String> productIds,
    final List<PromoCodeRedemption> redemptions,
  }) = _$PromoCodeImpl;

  @override
  String get id;
  @override
  String get code;
  @override
  int get percent;
  @override
  bool get isActive;
  @override
  int get usesCount;
  @override
  int get maxUsesPerClient;
  @override
  String? get label;
  @override
  DateTime? get startsAt;
  @override
  DateTime? get endsAt;

  /// `null` = sans plafond global.
  @override
  int? get maxUses;
  @override
  int? get minOrderFcfa;
  @override
  List<String> get productIds;
  @override
  List<PromoCodeRedemption> get redemptions;

  /// Create a copy of PromoCode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PromoCodeImplCopyWith<_$PromoCodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PromoCodeRedemption {
  String get id => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  int get discountFcfa => throw _privateConstructorUsedError;
  String get clientName => throw _privateConstructorUsedError;
  List<PromoCodeRedemptionItem> get items => throw _privateConstructorUsedError;

  /// Create a copy of PromoCodeRedemption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PromoCodeRedemptionCopyWith<PromoCodeRedemption> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromoCodeRedemptionCopyWith<$Res> {
  factory $PromoCodeRedemptionCopyWith(
    PromoCodeRedemption value,
    $Res Function(PromoCodeRedemption) then,
  ) = _$PromoCodeRedemptionCopyWithImpl<$Res, PromoCodeRedemption>;
  @useResult
  $Res call({
    String id,
    DateTime createdAt,
    int discountFcfa,
    String clientName,
    List<PromoCodeRedemptionItem> items,
  });
}

/// @nodoc
class _$PromoCodeRedemptionCopyWithImpl<$Res, $Val extends PromoCodeRedemption>
    implements $PromoCodeRedemptionCopyWith<$Res> {
  _$PromoCodeRedemptionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PromoCodeRedemption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? discountFcfa = null,
    Object? clientName = null,
    Object? items = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            discountFcfa: null == discountFcfa
                ? _value.discountFcfa
                : discountFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            clientName: null == clientName
                ? _value.clientName
                : clientName // ignore: cast_nullable_to_non_nullable
                      as String,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<PromoCodeRedemptionItem>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromoCodeRedemptionImplCopyWith<$Res>
    implements $PromoCodeRedemptionCopyWith<$Res> {
  factory _$$PromoCodeRedemptionImplCopyWith(
    _$PromoCodeRedemptionImpl value,
    $Res Function(_$PromoCodeRedemptionImpl) then,
  ) = __$$PromoCodeRedemptionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    DateTime createdAt,
    int discountFcfa,
    String clientName,
    List<PromoCodeRedemptionItem> items,
  });
}

/// @nodoc
class __$$PromoCodeRedemptionImplCopyWithImpl<$Res>
    extends _$PromoCodeRedemptionCopyWithImpl<$Res, _$PromoCodeRedemptionImpl>
    implements _$$PromoCodeRedemptionImplCopyWith<$Res> {
  __$$PromoCodeRedemptionImplCopyWithImpl(
    _$PromoCodeRedemptionImpl _value,
    $Res Function(_$PromoCodeRedemptionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PromoCodeRedemption
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? createdAt = null,
    Object? discountFcfa = null,
    Object? clientName = null,
    Object? items = null,
  }) {
    return _then(
      _$PromoCodeRedemptionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        discountFcfa: null == discountFcfa
            ? _value.discountFcfa
            : discountFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        clientName: null == clientName
            ? _value.clientName
            : clientName // ignore: cast_nullable_to_non_nullable
                  as String,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<PromoCodeRedemptionItem>,
      ),
    );
  }
}

/// @nodoc

class _$PromoCodeRedemptionImpl implements _PromoCodeRedemption {
  const _$PromoCodeRedemptionImpl({
    required this.id,
    required this.createdAt,
    required this.discountFcfa,
    required this.clientName,
    final List<PromoCodeRedemptionItem> items = const [],
  }) : _items = items;

  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final int discountFcfa;
  @override
  final String clientName;
  final List<PromoCodeRedemptionItem> _items;
  @override
  @JsonKey()
  List<PromoCodeRedemptionItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  String toString() {
    return 'PromoCodeRedemption(id: $id, createdAt: $createdAt, discountFcfa: $discountFcfa, clientName: $clientName, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromoCodeRedemptionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.discountFcfa, discountFcfa) ||
                other.discountFcfa == discountFcfa) &&
            (identical(other.clientName, clientName) ||
                other.clientName == clientName) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    createdAt,
    discountFcfa,
    clientName,
    const DeepCollectionEquality().hash(_items),
  );

  /// Create a copy of PromoCodeRedemption
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PromoCodeRedemptionImplCopyWith<_$PromoCodeRedemptionImpl> get copyWith =>
      __$$PromoCodeRedemptionImplCopyWithImpl<_$PromoCodeRedemptionImpl>(
        this,
        _$identity,
      );
}

abstract class _PromoCodeRedemption implements PromoCodeRedemption {
  const factory _PromoCodeRedemption({
    required final String id,
    required final DateTime createdAt,
    required final int discountFcfa,
    required final String clientName,
    final List<PromoCodeRedemptionItem> items,
  }) = _$PromoCodeRedemptionImpl;

  @override
  String get id;
  @override
  DateTime get createdAt;
  @override
  int get discountFcfa;
  @override
  String get clientName;
  @override
  List<PromoCodeRedemptionItem> get items;

  /// Create a copy of PromoCodeRedemption
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PromoCodeRedemptionImplCopyWith<_$PromoCodeRedemptionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PromoCodeRedemptionItem {
  String get productName => throw _privateConstructorUsedError;
  int get quantity => throw _privateConstructorUsedError;
  int get unitDiscountFcfa => throw _privateConstructorUsedError;

  /// Create a copy of PromoCodeRedemptionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PromoCodeRedemptionItemCopyWith<PromoCodeRedemptionItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromoCodeRedemptionItemCopyWith<$Res> {
  factory $PromoCodeRedemptionItemCopyWith(
    PromoCodeRedemptionItem value,
    $Res Function(PromoCodeRedemptionItem) then,
  ) = _$PromoCodeRedemptionItemCopyWithImpl<$Res, PromoCodeRedemptionItem>;
  @useResult
  $Res call({String productName, int quantity, int unitDiscountFcfa});
}

/// @nodoc
class _$PromoCodeRedemptionItemCopyWithImpl<
  $Res,
  $Val extends PromoCodeRedemptionItem
>
    implements $PromoCodeRedemptionItemCopyWith<$Res> {
  _$PromoCodeRedemptionItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PromoCodeRedemptionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productName = null,
    Object? quantity = null,
    Object? unitDiscountFcfa = null,
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
            unitDiscountFcfa: null == unitDiscountFcfa
                ? _value.unitDiscountFcfa
                : unitDiscountFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromoCodeRedemptionItemImplCopyWith<$Res>
    implements $PromoCodeRedemptionItemCopyWith<$Res> {
  factory _$$PromoCodeRedemptionItemImplCopyWith(
    _$PromoCodeRedemptionItemImpl value,
    $Res Function(_$PromoCodeRedemptionItemImpl) then,
  ) = __$$PromoCodeRedemptionItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String productName, int quantity, int unitDiscountFcfa});
}

/// @nodoc
class __$$PromoCodeRedemptionItemImplCopyWithImpl<$Res>
    extends
        _$PromoCodeRedemptionItemCopyWithImpl<
          $Res,
          _$PromoCodeRedemptionItemImpl
        >
    implements _$$PromoCodeRedemptionItemImplCopyWith<$Res> {
  __$$PromoCodeRedemptionItemImplCopyWithImpl(
    _$PromoCodeRedemptionItemImpl _value,
    $Res Function(_$PromoCodeRedemptionItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PromoCodeRedemptionItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productName = null,
    Object? quantity = null,
    Object? unitDiscountFcfa = null,
  }) {
    return _then(
      _$PromoCodeRedemptionItemImpl(
        productName: null == productName
            ? _value.productName
            : productName // ignore: cast_nullable_to_non_nullable
                  as String,
        quantity: null == quantity
            ? _value.quantity
            : quantity // ignore: cast_nullable_to_non_nullable
                  as int,
        unitDiscountFcfa: null == unitDiscountFcfa
            ? _value.unitDiscountFcfa
            : unitDiscountFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$PromoCodeRedemptionItemImpl implements _PromoCodeRedemptionItem {
  const _$PromoCodeRedemptionItemImpl({
    required this.productName,
    required this.quantity,
    required this.unitDiscountFcfa,
  });

  @override
  final String productName;
  @override
  final int quantity;
  @override
  final int unitDiscountFcfa;

  @override
  String toString() {
    return 'PromoCodeRedemptionItem(productName: $productName, quantity: $quantity, unitDiscountFcfa: $unitDiscountFcfa)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromoCodeRedemptionItemImpl &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unitDiscountFcfa, unitDiscountFcfa) ||
                other.unitDiscountFcfa == unitDiscountFcfa));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, productName, quantity, unitDiscountFcfa);

  /// Create a copy of PromoCodeRedemptionItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PromoCodeRedemptionItemImplCopyWith<_$PromoCodeRedemptionItemImpl>
  get copyWith =>
      __$$PromoCodeRedemptionItemImplCopyWithImpl<
        _$PromoCodeRedemptionItemImpl
      >(this, _$identity);
}

abstract class _PromoCodeRedemptionItem implements PromoCodeRedemptionItem {
  const factory _PromoCodeRedemptionItem({
    required final String productName,
    required final int quantity,
    required final int unitDiscountFcfa,
  }) = _$PromoCodeRedemptionItemImpl;

  @override
  String get productName;
  @override
  int get quantity;
  @override
  int get unitDiscountFcfa;

  /// Create a copy of PromoCodeRedemptionItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PromoCodeRedemptionItemImplCopyWith<_$PromoCodeRedemptionItemImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$PromoCodePreview {
  bool get valid => throw _privateConstructorUsedError;
  String? get reason => throw _privateConstructorUsedError;
  String? get code => throw _privateConstructorUsedError;
  int? get percent => throw _privateConstructorUsedError;
  String? get supplierId => throw _privateConstructorUsedError;
  int get discountFcfa => throw _privateConstructorUsedError;

  /// Create a copy of PromoCodePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PromoCodePreviewCopyWith<PromoCodePreview> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PromoCodePreviewCopyWith<$Res> {
  factory $PromoCodePreviewCopyWith(
    PromoCodePreview value,
    $Res Function(PromoCodePreview) then,
  ) = _$PromoCodePreviewCopyWithImpl<$Res, PromoCodePreview>;
  @useResult
  $Res call({
    bool valid,
    String? reason,
    String? code,
    int? percent,
    String? supplierId,
    int discountFcfa,
  });
}

/// @nodoc
class _$PromoCodePreviewCopyWithImpl<$Res, $Val extends PromoCodePreview>
    implements $PromoCodePreviewCopyWith<$Res> {
  _$PromoCodePreviewCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of PromoCodePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? valid = null,
    Object? reason = freezed,
    Object? code = freezed,
    Object? percent = freezed,
    Object? supplierId = freezed,
    Object? discountFcfa = null,
  }) {
    return _then(
      _value.copyWith(
            valid: null == valid
                ? _value.valid
                : valid // ignore: cast_nullable_to_non_nullable
                      as bool,
            reason: freezed == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String?,
            code: freezed == code
                ? _value.code
                : code // ignore: cast_nullable_to_non_nullable
                      as String?,
            percent: freezed == percent
                ? _value.percent
                : percent // ignore: cast_nullable_to_non_nullable
                      as int?,
            supplierId: freezed == supplierId
                ? _value.supplierId
                : supplierId // ignore: cast_nullable_to_non_nullable
                      as String?,
            discountFcfa: null == discountFcfa
                ? _value.discountFcfa
                : discountFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$PromoCodePreviewImplCopyWith<$Res>
    implements $PromoCodePreviewCopyWith<$Res> {
  factory _$$PromoCodePreviewImplCopyWith(
    _$PromoCodePreviewImpl value,
    $Res Function(_$PromoCodePreviewImpl) then,
  ) = __$$PromoCodePreviewImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool valid,
    String? reason,
    String? code,
    int? percent,
    String? supplierId,
    int discountFcfa,
  });
}

/// @nodoc
class __$$PromoCodePreviewImplCopyWithImpl<$Res>
    extends _$PromoCodePreviewCopyWithImpl<$Res, _$PromoCodePreviewImpl>
    implements _$$PromoCodePreviewImplCopyWith<$Res> {
  __$$PromoCodePreviewImplCopyWithImpl(
    _$PromoCodePreviewImpl _value,
    $Res Function(_$PromoCodePreviewImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of PromoCodePreview
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? valid = null,
    Object? reason = freezed,
    Object? code = freezed,
    Object? percent = freezed,
    Object? supplierId = freezed,
    Object? discountFcfa = null,
  }) {
    return _then(
      _$PromoCodePreviewImpl(
        valid: null == valid
            ? _value.valid
            : valid // ignore: cast_nullable_to_non_nullable
                  as bool,
        reason: freezed == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String?,
        code: freezed == code
            ? _value.code
            : code // ignore: cast_nullable_to_non_nullable
                  as String?,
        percent: freezed == percent
            ? _value.percent
            : percent // ignore: cast_nullable_to_non_nullable
                  as int?,
        supplierId: freezed == supplierId
            ? _value.supplierId
            : supplierId // ignore: cast_nullable_to_non_nullable
                  as String?,
        discountFcfa: null == discountFcfa
            ? _value.discountFcfa
            : discountFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$PromoCodePreviewImpl implements _PromoCodePreview {
  const _$PromoCodePreviewImpl({
    required this.valid,
    this.reason,
    this.code,
    this.percent,
    this.supplierId,
    this.discountFcfa = 0,
  });

  @override
  final bool valid;
  @override
  final String? reason;
  @override
  final String? code;
  @override
  final int? percent;
  @override
  final String? supplierId;
  @override
  @JsonKey()
  final int discountFcfa;

  @override
  String toString() {
    return 'PromoCodePreview(valid: $valid, reason: $reason, code: $code, percent: $percent, supplierId: $supplierId, discountFcfa: $discountFcfa)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PromoCodePreviewImpl &&
            (identical(other.valid, valid) || other.valid == valid) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.percent, percent) || other.percent == percent) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.discountFcfa, discountFcfa) ||
                other.discountFcfa == discountFcfa));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    valid,
    reason,
    code,
    percent,
    supplierId,
    discountFcfa,
  );

  /// Create a copy of PromoCodePreview
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PromoCodePreviewImplCopyWith<_$PromoCodePreviewImpl> get copyWith =>
      __$$PromoCodePreviewImplCopyWithImpl<_$PromoCodePreviewImpl>(
        this,
        _$identity,
      );
}

abstract class _PromoCodePreview implements PromoCodePreview {
  const factory _PromoCodePreview({
    required final bool valid,
    final String? reason,
    final String? code,
    final int? percent,
    final String? supplierId,
    final int discountFcfa,
  }) = _$PromoCodePreviewImpl;

  @override
  bool get valid;
  @override
  String? get reason;
  @override
  String? get code;
  @override
  int? get percent;
  @override
  String? get supplierId;
  @override
  int get discountFcfa;

  /// Create a copy of PromoCodePreview
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PromoCodePreviewImplCopyWith<_$PromoCodePreviewImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
