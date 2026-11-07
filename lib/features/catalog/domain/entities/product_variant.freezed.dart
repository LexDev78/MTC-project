// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_variant.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ProductVariantOptionRef _$ProductVariantOptionRefFromJson(
  Map<String, dynamic> json,
) {
  return _ProductVariantOptionRef.fromJson(json);
}

/// @nodoc
mixin _$ProductVariantOptionRef {
  String get characteristicId => throw _privateConstructorUsedError;
  String get optionId => throw _privateConstructorUsedError;

  /// Serializes this ProductVariantOptionRef to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductVariantOptionRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductVariantOptionRefCopyWith<ProductVariantOptionRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductVariantOptionRefCopyWith<$Res> {
  factory $ProductVariantOptionRefCopyWith(
    ProductVariantOptionRef value,
    $Res Function(ProductVariantOptionRef) then,
  ) = _$ProductVariantOptionRefCopyWithImpl<$Res, ProductVariantOptionRef>;
  @useResult
  $Res call({String characteristicId, String optionId});
}

/// @nodoc
class _$ProductVariantOptionRefCopyWithImpl<
  $Res,
  $Val extends ProductVariantOptionRef
>
    implements $ProductVariantOptionRefCopyWith<$Res> {
  _$ProductVariantOptionRefCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductVariantOptionRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? characteristicId = null, Object? optionId = null}) {
    return _then(
      _value.copyWith(
            characteristicId: null == characteristicId
                ? _value.characteristicId
                : characteristicId // ignore: cast_nullable_to_non_nullable
                      as String,
            optionId: null == optionId
                ? _value.optionId
                : optionId // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductVariantOptionRefImplCopyWith<$Res>
    implements $ProductVariantOptionRefCopyWith<$Res> {
  factory _$$ProductVariantOptionRefImplCopyWith(
    _$ProductVariantOptionRefImpl value,
    $Res Function(_$ProductVariantOptionRefImpl) then,
  ) = __$$ProductVariantOptionRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String characteristicId, String optionId});
}

/// @nodoc
class __$$ProductVariantOptionRefImplCopyWithImpl<$Res>
    extends
        _$ProductVariantOptionRefCopyWithImpl<
          $Res,
          _$ProductVariantOptionRefImpl
        >
    implements _$$ProductVariantOptionRefImplCopyWith<$Res> {
  __$$ProductVariantOptionRefImplCopyWithImpl(
    _$ProductVariantOptionRefImpl _value,
    $Res Function(_$ProductVariantOptionRefImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductVariantOptionRef
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? characteristicId = null, Object? optionId = null}) {
    return _then(
      _$ProductVariantOptionRefImpl(
        characteristicId: null == characteristicId
            ? _value.characteristicId
            : characteristicId // ignore: cast_nullable_to_non_nullable
                  as String,
        optionId: null == optionId
            ? _value.optionId
            : optionId // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductVariantOptionRefImpl implements _ProductVariantOptionRef {
  const _$ProductVariantOptionRefImpl({
    required this.characteristicId,
    required this.optionId,
  });

  factory _$ProductVariantOptionRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductVariantOptionRefImplFromJson(json);

  @override
  final String characteristicId;
  @override
  final String optionId;

  @override
  String toString() {
    return 'ProductVariantOptionRef(characteristicId: $characteristicId, optionId: $optionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductVariantOptionRefImpl &&
            (identical(other.characteristicId, characteristicId) ||
                other.characteristicId == characteristicId) &&
            (identical(other.optionId, optionId) ||
                other.optionId == optionId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, characteristicId, optionId);

  /// Create a copy of ProductVariantOptionRef
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductVariantOptionRefImplCopyWith<_$ProductVariantOptionRefImpl>
  get copyWith =>
      __$$ProductVariantOptionRefImplCopyWithImpl<
        _$ProductVariantOptionRefImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductVariantOptionRefImplToJson(this);
  }
}

abstract class _ProductVariantOptionRef implements ProductVariantOptionRef {
  const factory _ProductVariantOptionRef({
    required final String characteristicId,
    required final String optionId,
  }) = _$ProductVariantOptionRefImpl;

  factory _ProductVariantOptionRef.fromJson(Map<String, dynamic> json) =
      _$ProductVariantOptionRefImpl.fromJson;

  @override
  String get characteristicId;
  @override
  String get optionId;

  /// Create a copy of ProductVariantOptionRef
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductVariantOptionRefImplCopyWith<_$ProductVariantOptionRefImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ProductVariant _$ProductVariantFromJson(Map<String, dynamic> json) {
  return _ProductVariant.fromJson(json);
}

/// @nodoc
mixin _$ProductVariant {
  String get id => throw _privateConstructorUsedError;
  String get productId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  int get priceFcfa => throw _privateConstructorUsedError;
  int get stockQuantity => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;

  /// Chemin d'objet Storage d'une courte vidéo de présentation (bucket
  /// `product-videos`, `0044_variant_video.sql`), jamais une URL résolue —
  /// même convention que [imageUrls]. `null` tant que le fournisseur n'en
  /// a pas ajouté, ce qui est le cas de l'immense majorité des variantes.
  String? get videoPath => throw _privateConstructorUsedError;
  bool get isDefault => throw _privateConstructorUsedError;
  int get displayOrder =>
      throw _privateConstructorUsedError; // ignore: invalid_annotation_target
  @JsonKey(name: 'variant_options')
  List<ProductVariantOptionRef> get optionRefs =>
      throw _privateConstructorUsedError;

  /// Serializes this ProductVariant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ProductVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductVariantCopyWith<ProductVariant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductVariantCopyWith<$Res> {
  factory $ProductVariantCopyWith(
    ProductVariant value,
    $Res Function(ProductVariant) then,
  ) = _$ProductVariantCopyWithImpl<$Res, ProductVariant>;
  @useResult
  $Res call({
    String id,
    String productId,
    String name,
    int priceFcfa,
    int stockQuantity,
    List<String> imageUrls,
    String? videoPath,
    bool isDefault,
    int displayOrder,
    @JsonKey(name: 'variant_options') List<ProductVariantOptionRef> optionRefs,
  });
}

/// @nodoc
class _$ProductVariantCopyWithImpl<$Res, $Val extends ProductVariant>
    implements $ProductVariantCopyWith<$Res> {
  _$ProductVariantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ProductVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? name = null,
    Object? priceFcfa = null,
    Object? stockQuantity = null,
    Object? imageUrls = null,
    Object? videoPath = freezed,
    Object? isDefault = null,
    Object? displayOrder = null,
    Object? optionRefs = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            priceFcfa: null == priceFcfa
                ? _value.priceFcfa
                : priceFcfa // ignore: cast_nullable_to_non_nullable
                      as int,
            stockQuantity: null == stockQuantity
                ? _value.stockQuantity
                : stockQuantity // ignore: cast_nullable_to_non_nullable
                      as int,
            imageUrls: null == imageUrls
                ? _value.imageUrls
                : imageUrls // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            videoPath: freezed == videoPath
                ? _value.videoPath
                : videoPath // ignore: cast_nullable_to_non_nullable
                      as String?,
            isDefault: null == isDefault
                ? _value.isDefault
                : isDefault // ignore: cast_nullable_to_non_nullable
                      as bool,
            displayOrder: null == displayOrder
                ? _value.displayOrder
                : displayOrder // ignore: cast_nullable_to_non_nullable
                      as int,
            optionRefs: null == optionRefs
                ? _value.optionRefs
                : optionRefs // ignore: cast_nullable_to_non_nullable
                      as List<ProductVariantOptionRef>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductVariantImplCopyWith<$Res>
    implements $ProductVariantCopyWith<$Res> {
  factory _$$ProductVariantImplCopyWith(
    _$ProductVariantImpl value,
    $Res Function(_$ProductVariantImpl) then,
  ) = __$$ProductVariantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String productId,
    String name,
    int priceFcfa,
    int stockQuantity,
    List<String> imageUrls,
    String? videoPath,
    bool isDefault,
    int displayOrder,
    @JsonKey(name: 'variant_options') List<ProductVariantOptionRef> optionRefs,
  });
}

/// @nodoc
class __$$ProductVariantImplCopyWithImpl<$Res>
    extends _$ProductVariantCopyWithImpl<$Res, _$ProductVariantImpl>
    implements _$$ProductVariantImplCopyWith<$Res> {
  __$$ProductVariantImplCopyWithImpl(
    _$ProductVariantImpl _value,
    $Res Function(_$ProductVariantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ProductVariant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? productId = null,
    Object? name = null,
    Object? priceFcfa = null,
    Object? stockQuantity = null,
    Object? imageUrls = null,
    Object? videoPath = freezed,
    Object? isDefault = null,
    Object? displayOrder = null,
    Object? optionRefs = null,
  }) {
    return _then(
      _$ProductVariantImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        priceFcfa: null == priceFcfa
            ? _value.priceFcfa
            : priceFcfa // ignore: cast_nullable_to_non_nullable
                  as int,
        stockQuantity: null == stockQuantity
            ? _value.stockQuantity
            : stockQuantity // ignore: cast_nullable_to_non_nullable
                  as int,
        imageUrls: null == imageUrls
            ? _value._imageUrls
            : imageUrls // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        videoPath: freezed == videoPath
            ? _value.videoPath
            : videoPath // ignore: cast_nullable_to_non_nullable
                  as String?,
        isDefault: null == isDefault
            ? _value.isDefault
            : isDefault // ignore: cast_nullable_to_non_nullable
                  as bool,
        displayOrder: null == displayOrder
            ? _value.displayOrder
            : displayOrder // ignore: cast_nullable_to_non_nullable
                  as int,
        optionRefs: null == optionRefs
            ? _value._optionRefs
            : optionRefs // ignore: cast_nullable_to_non_nullable
                  as List<ProductVariantOptionRef>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductVariantImpl implements _ProductVariant {
  const _$ProductVariantImpl({
    required this.id,
    required this.productId,
    required this.name,
    required this.priceFcfa,
    required this.stockQuantity,
    final List<String> imageUrls = const [],
    this.videoPath,
    this.isDefault = false,
    this.displayOrder = 0,
    @JsonKey(name: 'variant_options')
    final List<ProductVariantOptionRef> optionRefs = const [],
  }) : _imageUrls = imageUrls,
       _optionRefs = optionRefs;

  factory _$ProductVariantImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductVariantImplFromJson(json);

  @override
  final String id;
  @override
  final String productId;
  @override
  final String name;
  @override
  final int priceFcfa;
  @override
  final int stockQuantity;
  final List<String> _imageUrls;
  @override
  @JsonKey()
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  /// Chemin d'objet Storage d'une courte vidéo de présentation (bucket
  /// `product-videos`, `0044_variant_video.sql`), jamais une URL résolue —
  /// même convention que [imageUrls]. `null` tant que le fournisseur n'en
  /// a pas ajouté, ce qui est le cas de l'immense majorité des variantes.
  @override
  final String? videoPath;
  @override
  @JsonKey()
  final bool isDefault;
  @override
  @JsonKey()
  final int displayOrder;
  // ignore: invalid_annotation_target
  final List<ProductVariantOptionRef> _optionRefs;
  // ignore: invalid_annotation_target
  @override
  @JsonKey(name: 'variant_options')
  List<ProductVariantOptionRef> get optionRefs {
    if (_optionRefs is EqualUnmodifiableListView) return _optionRefs;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_optionRefs);
  }

  @override
  String toString() {
    return 'ProductVariant(id: $id, productId: $productId, name: $name, priceFcfa: $priceFcfa, stockQuantity: $stockQuantity, imageUrls: $imageUrls, videoPath: $videoPath, isDefault: $isDefault, displayOrder: $displayOrder, optionRefs: $optionRefs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductVariantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.priceFcfa, priceFcfa) ||
                other.priceFcfa == priceFcfa) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.videoPath, videoPath) ||
                other.videoPath == videoPath) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault) &&
            (identical(other.displayOrder, displayOrder) ||
                other.displayOrder == displayOrder) &&
            const DeepCollectionEquality().equals(
              other._optionRefs,
              _optionRefs,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    productId,
    name,
    priceFcfa,
    stockQuantity,
    const DeepCollectionEquality().hash(_imageUrls),
    videoPath,
    isDefault,
    displayOrder,
    const DeepCollectionEquality().hash(_optionRefs),
  );

  /// Create a copy of ProductVariant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductVariantImplCopyWith<_$ProductVariantImpl> get copyWith =>
      __$$ProductVariantImplCopyWithImpl<_$ProductVariantImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductVariantImplToJson(this);
  }
}

abstract class _ProductVariant implements ProductVariant {
  const factory _ProductVariant({
    required final String id,
    required final String productId,
    required final String name,
    required final int priceFcfa,
    required final int stockQuantity,
    final List<String> imageUrls,
    final String? videoPath,
    final bool isDefault,
    final int displayOrder,
    @JsonKey(name: 'variant_options')
    final List<ProductVariantOptionRef> optionRefs,
  }) = _$ProductVariantImpl;

  factory _ProductVariant.fromJson(Map<String, dynamic> json) =
      _$ProductVariantImpl.fromJson;

  @override
  String get id;
  @override
  String get productId;
  @override
  String get name;
  @override
  int get priceFcfa;
  @override
  int get stockQuantity;
  @override
  List<String> get imageUrls;

  /// Chemin d'objet Storage d'une courte vidéo de présentation (bucket
  /// `product-videos`, `0044_variant_video.sql`), jamais une URL résolue —
  /// même convention que [imageUrls]. `null` tant que le fournisseur n'en
  /// a pas ajouté, ce qui est le cas de l'immense majorité des variantes.
  @override
  String? get videoPath;
  @override
  bool get isDefault;
  @override
  int get displayOrder; // ignore: invalid_annotation_target
  @override
  @JsonKey(name: 'variant_options')
  List<ProductVariantOptionRef> get optionRefs;

  /// Create a copy of ProductVariant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductVariantImplCopyWith<_$ProductVariantImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
