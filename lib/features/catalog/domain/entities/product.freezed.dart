// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Product _$ProductFromJson(Map<String, dynamic> json) {
  return _Product.fromJson(json);
}

/// @nodoc
mixin _$Product {
  String get id => throw _privateConstructorUsedError;
  String get supplierId => throw _privateConstructorUsedError;
  String get supplierName => throw _privateConstructorUsedError;
  SupplierType get supplierType => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  ProductCategory get category => throw _privateConstructorUsedError;
  int get priceFcfa => throw _privateConstructorUsedError;
  int get stockQuantity => throw _privateConstructorUsedError;
  List<String> get imageUrls => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  double get ratingAverage => throw _privateConstructorUsedError;
  int get ratingCount => throw _privateConstructorUsedError;
  bool get allowsSelfDelivery => throw _privateConstructorUsedError;
  bool get allowsMtcDelivery => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Shipping weight — feeds `computeHomeDeliveryFeeFcfa`
  /// (features/orders/domain/delivery_pricing.dart) alongside distance and
  /// category, so heavier items cost more to have MTC deliver. No longer
  /// a flat per-product fee: that's computed per order, per destination.
  double get weightKg => throw _privateConstructorUsedError;

  /// Denormalized from the supplier's verification status. Products from
  /// unverified/pending tiers suppliers are excluded from client-facing
  /// catalog queries — visibility on the platform is earned through
  /// verification + rating, per the product's trust model.
  bool get isSupplierVerified => throw _privateConstructorUsedError;

  /// Selectable variants — empty when the product doesn't have that axis
  /// (e.g. a bag of cement has no size/color). Kept as plain label lists
  /// rather than a richer variant-pricing model since price doesn't
  /// change per variant in this catalog yet.
  List<String> get sizes => throw _privateConstructorUsedError;
  List<String> get colors => throw _privateConstructorUsedError;

  /// Where the product is manufactured/sourced from — defaults to Mali
  /// since most of the seeded catalog is local artisanal/agricultural
  /// goods; imported categories (electronics, some materials) override it.
  ProductRegion get region => throw _privateConstructorUsedError;

  /// Lifecycle within the supplier's own catalog management — see
  /// `ProductStatus`'s doc comment. Defaults to `active` so every
  /// pre-existing seeded product (created before this field existed)
  /// stays visible without a data migration.
  ProductStatus get status => throw _privateConstructorUsedError;

  /// Below this stock level, the supplier's product list flags the item
  /// as low — `null` means no threshold is set (no warning is ever
  /// shown). A per-product setting rather than a platform-wide constant
  /// since restock lead time varies a lot by category (e.g. imported
  /// electronics vs. locally-milled rice).
  int? get lowStockThreshold => throw _privateConstructorUsedError;

  /// The pre-discount price, shown struck through next to [priceFcfa]
  /// when set and higher than it — a plain "barré" price, not a
  /// scheduled/rule-based promotion engine.
  int? get compareAtPriceFcfa => throw _privateConstructorUsedError;

  /// Bumped by [ProductRepository.incrementViewCount] once per client
  /// visit to the product's detail page — shown on the supplier
  /// dashboard, not client-facing anywhere.
  int get viewCount => throw _privateConstructorUsedError;

  /// Trigger-maintained (`0018_product_variants.sql`) — the only
  /// reliable "does this product have variants" signal, true even from
  /// list queries (`watchProducts`/`watchMyProducts`) that don't embed
  /// [characteristics]/[variants] below. Never infer this from
  /// `characteristics.isEmpty`/`variants.isEmpty`: those are only
  /// populated by `getById`'s nested select.
  bool get hasVariants => throw _privateConstructorUsedError;

  /// Trigger-maintained max variant price — `null` unless [hasVariants].
  /// Paired with [priceFcfa] (trigger-maintained min variant price once
  /// variants exist) to render "à partir de" range pricing without
  /// fetching [variants].
  int? get maxPriceFcfa => throw _privateConstructorUsedError;

  /// Trigger-maintained count of this product's variants — `0` unless
  /// [hasVariants]. Lets list views show "N variantes" without embedding
  /// the full [variants] list.
  int get variantCount => throw _privateConstructorUsedError;

  /// This product's characteristics (couleur/stockage/...), each with its
  /// own options — only populated via `getById`'s nested select (product
  /// detail, cart line, checkout, favorites resolve, chat attachment,
  /// stock-adjust sheet). Always empty from list queries.
  List<ProductCharacteristic> get characteristics =>
      throw _privateConstructorUsedError;

  /// This product's purchasable variants — same nested-select-only
  /// population as [characteristics].
  List<ProductVariant> get variants => throw _privateConstructorUsedError;

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ProductCopyWith<Product> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ProductCopyWith<$Res> {
  factory $ProductCopyWith(Product value, $Res Function(Product) then) =
      _$ProductCopyWithImpl<$Res, Product>;
  @useResult
  $Res call({
    String id,
    String supplierId,
    String supplierName,
    SupplierType supplierType,
    String name,
    String description,
    ProductCategory category,
    int priceFcfa,
    int stockQuantity,
    List<String> imageUrls,
    String city,
    double ratingAverage,
    int ratingCount,
    bool allowsSelfDelivery,
    bool allowsMtcDelivery,
    DateTime createdAt,
    double weightKg,
    bool isSupplierVerified,
    List<String> sizes,
    List<String> colors,
    ProductRegion region,
    ProductStatus status,
    int? lowStockThreshold,
    int? compareAtPriceFcfa,
    int viewCount,
    bool hasVariants,
    int? maxPriceFcfa,
    int variantCount,
    List<ProductCharacteristic> characteristics,
    List<ProductVariant> variants,
  });
}

/// @nodoc
class _$ProductCopyWithImpl<$Res, $Val extends Product>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? supplierType = null,
    Object? name = null,
    Object? description = null,
    Object? category = null,
    Object? priceFcfa = null,
    Object? stockQuantity = null,
    Object? imageUrls = null,
    Object? city = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
    Object? allowsSelfDelivery = null,
    Object? allowsMtcDelivery = null,
    Object? createdAt = null,
    Object? weightKg = null,
    Object? isSupplierVerified = null,
    Object? sizes = null,
    Object? colors = null,
    Object? region = null,
    Object? status = null,
    Object? lowStockThreshold = freezed,
    Object? compareAtPriceFcfa = freezed,
    Object? viewCount = null,
    Object? hasVariants = null,
    Object? maxPriceFcfa = freezed,
    Object? variantCount = null,
    Object? characteristics = null,
    Object? variants = null,
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
            supplierType: null == supplierType
                ? _value.supplierType
                : supplierType // ignore: cast_nullable_to_non_nullable
                      as SupplierType,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as ProductCategory,
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
            allowsSelfDelivery: null == allowsSelfDelivery
                ? _value.allowsSelfDelivery
                : allowsSelfDelivery // ignore: cast_nullable_to_non_nullable
                      as bool,
            allowsMtcDelivery: null == allowsMtcDelivery
                ? _value.allowsMtcDelivery
                : allowsMtcDelivery // ignore: cast_nullable_to_non_nullable
                      as bool,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            weightKg: null == weightKg
                ? _value.weightKg
                : weightKg // ignore: cast_nullable_to_non_nullable
                      as double,
            isSupplierVerified: null == isSupplierVerified
                ? _value.isSupplierVerified
                : isSupplierVerified // ignore: cast_nullable_to_non_nullable
                      as bool,
            sizes: null == sizes
                ? _value.sizes
                : sizes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            colors: null == colors
                ? _value.colors
                : colors // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            region: null == region
                ? _value.region
                : region // ignore: cast_nullable_to_non_nullable
                      as ProductRegion,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ProductStatus,
            lowStockThreshold: freezed == lowStockThreshold
                ? _value.lowStockThreshold
                : lowStockThreshold // ignore: cast_nullable_to_non_nullable
                      as int?,
            compareAtPriceFcfa: freezed == compareAtPriceFcfa
                ? _value.compareAtPriceFcfa
                : compareAtPriceFcfa // ignore: cast_nullable_to_non_nullable
                      as int?,
            viewCount: null == viewCount
                ? _value.viewCount
                : viewCount // ignore: cast_nullable_to_non_nullable
                      as int,
            hasVariants: null == hasVariants
                ? _value.hasVariants
                : hasVariants // ignore: cast_nullable_to_non_nullable
                      as bool,
            maxPriceFcfa: freezed == maxPriceFcfa
                ? _value.maxPriceFcfa
                : maxPriceFcfa // ignore: cast_nullable_to_non_nullable
                      as int?,
            variantCount: null == variantCount
                ? _value.variantCount
                : variantCount // ignore: cast_nullable_to_non_nullable
                      as int,
            characteristics: null == characteristics
                ? _value.characteristics
                : characteristics // ignore: cast_nullable_to_non_nullable
                      as List<ProductCharacteristic>,
            variants: null == variants
                ? _value.variants
                : variants // ignore: cast_nullable_to_non_nullable
                      as List<ProductVariant>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ProductImplCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$$ProductImplCopyWith(
    _$ProductImpl value,
    $Res Function(_$ProductImpl) then,
  ) = __$$ProductImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String supplierId,
    String supplierName,
    SupplierType supplierType,
    String name,
    String description,
    ProductCategory category,
    int priceFcfa,
    int stockQuantity,
    List<String> imageUrls,
    String city,
    double ratingAverage,
    int ratingCount,
    bool allowsSelfDelivery,
    bool allowsMtcDelivery,
    DateTime createdAt,
    double weightKg,
    bool isSupplierVerified,
    List<String> sizes,
    List<String> colors,
    ProductRegion region,
    ProductStatus status,
    int? lowStockThreshold,
    int? compareAtPriceFcfa,
    int viewCount,
    bool hasVariants,
    int? maxPriceFcfa,
    int variantCount,
    List<ProductCharacteristic> characteristics,
    List<ProductVariant> variants,
  });
}

/// @nodoc
class __$$ProductImplCopyWithImpl<$Res>
    extends _$ProductCopyWithImpl<$Res, _$ProductImpl>
    implements _$$ProductImplCopyWith<$Res> {
  __$$ProductImplCopyWithImpl(
    _$ProductImpl _value,
    $Res Function(_$ProductImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? supplierId = null,
    Object? supplierName = null,
    Object? supplierType = null,
    Object? name = null,
    Object? description = null,
    Object? category = null,
    Object? priceFcfa = null,
    Object? stockQuantity = null,
    Object? imageUrls = null,
    Object? city = null,
    Object? ratingAverage = null,
    Object? ratingCount = null,
    Object? allowsSelfDelivery = null,
    Object? allowsMtcDelivery = null,
    Object? createdAt = null,
    Object? weightKg = null,
    Object? isSupplierVerified = null,
    Object? sizes = null,
    Object? colors = null,
    Object? region = null,
    Object? status = null,
    Object? lowStockThreshold = freezed,
    Object? compareAtPriceFcfa = freezed,
    Object? viewCount = null,
    Object? hasVariants = null,
    Object? maxPriceFcfa = freezed,
    Object? variantCount = null,
    Object? characteristics = null,
    Object? variants = null,
  }) {
    return _then(
      _$ProductImpl(
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
        supplierType: null == supplierType
            ? _value.supplierType
            : supplierType // ignore: cast_nullable_to_non_nullable
                  as SupplierType,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as ProductCategory,
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
        allowsSelfDelivery: null == allowsSelfDelivery
            ? _value.allowsSelfDelivery
            : allowsSelfDelivery // ignore: cast_nullable_to_non_nullable
                  as bool,
        allowsMtcDelivery: null == allowsMtcDelivery
            ? _value.allowsMtcDelivery
            : allowsMtcDelivery // ignore: cast_nullable_to_non_nullable
                  as bool,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        weightKg: null == weightKg
            ? _value.weightKg
            : weightKg // ignore: cast_nullable_to_non_nullable
                  as double,
        isSupplierVerified: null == isSupplierVerified
            ? _value.isSupplierVerified
            : isSupplierVerified // ignore: cast_nullable_to_non_nullable
                  as bool,
        sizes: null == sizes
            ? _value._sizes
            : sizes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        colors: null == colors
            ? _value._colors
            : colors // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        region: null == region
            ? _value.region
            : region // ignore: cast_nullable_to_non_nullable
                  as ProductRegion,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ProductStatus,
        lowStockThreshold: freezed == lowStockThreshold
            ? _value.lowStockThreshold
            : lowStockThreshold // ignore: cast_nullable_to_non_nullable
                  as int?,
        compareAtPriceFcfa: freezed == compareAtPriceFcfa
            ? _value.compareAtPriceFcfa
            : compareAtPriceFcfa // ignore: cast_nullable_to_non_nullable
                  as int?,
        viewCount: null == viewCount
            ? _value.viewCount
            : viewCount // ignore: cast_nullable_to_non_nullable
                  as int,
        hasVariants: null == hasVariants
            ? _value.hasVariants
            : hasVariants // ignore: cast_nullable_to_non_nullable
                  as bool,
        maxPriceFcfa: freezed == maxPriceFcfa
            ? _value.maxPriceFcfa
            : maxPriceFcfa // ignore: cast_nullable_to_non_nullable
                  as int?,
        variantCount: null == variantCount
            ? _value.variantCount
            : variantCount // ignore: cast_nullable_to_non_nullable
                  as int,
        characteristics: null == characteristics
            ? _value._characteristics
            : characteristics // ignore: cast_nullable_to_non_nullable
                  as List<ProductCharacteristic>,
        variants: null == variants
            ? _value._variants
            : variants // ignore: cast_nullable_to_non_nullable
                  as List<ProductVariant>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ProductImpl implements _Product {
  const _$ProductImpl({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.supplierType,
    required this.name,
    required this.description,
    required this.category,
    required this.priceFcfa,
    required this.stockQuantity,
    required final List<String> imageUrls,
    required this.city,
    required this.ratingAverage,
    required this.ratingCount,
    required this.allowsSelfDelivery,
    required this.allowsMtcDelivery,
    required this.createdAt,
    required this.weightKg,
    this.isSupplierVerified = true,
    final List<String> sizes = const [],
    final List<String> colors = const [],
    this.region = ProductRegion.mali,
    this.status = ProductStatus.active,
    this.lowStockThreshold,
    this.compareAtPriceFcfa,
    this.viewCount = 0,
    this.hasVariants = false,
    this.maxPriceFcfa,
    this.variantCount = 0,
    final List<ProductCharacteristic> characteristics = const [],
    final List<ProductVariant> variants = const [],
  }) : _imageUrls = imageUrls,
       _sizes = sizes,
       _colors = colors,
       _characteristics = characteristics,
       _variants = variants;

  factory _$ProductImpl.fromJson(Map<String, dynamic> json) =>
      _$$ProductImplFromJson(json);

  @override
  final String id;
  @override
  final String supplierId;
  @override
  final String supplierName;
  @override
  final SupplierType supplierType;
  @override
  final String name;
  @override
  final String description;
  @override
  final ProductCategory category;
  @override
  final int priceFcfa;
  @override
  final int stockQuantity;
  final List<String> _imageUrls;
  @override
  List<String> get imageUrls {
    if (_imageUrls is EqualUnmodifiableListView) return _imageUrls;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_imageUrls);
  }

  @override
  final String city;
  @override
  final double ratingAverage;
  @override
  final int ratingCount;
  @override
  final bool allowsSelfDelivery;
  @override
  final bool allowsMtcDelivery;
  @override
  final DateTime createdAt;

  /// Shipping weight — feeds `computeHomeDeliveryFeeFcfa`
  /// (features/orders/domain/delivery_pricing.dart) alongside distance and
  /// category, so heavier items cost more to have MTC deliver. No longer
  /// a flat per-product fee: that's computed per order, per destination.
  @override
  final double weightKg;

  /// Denormalized from the supplier's verification status. Products from
  /// unverified/pending tiers suppliers are excluded from client-facing
  /// catalog queries — visibility on the platform is earned through
  /// verification + rating, per the product's trust model.
  @override
  @JsonKey()
  final bool isSupplierVerified;

  /// Selectable variants — empty when the product doesn't have that axis
  /// (e.g. a bag of cement has no size/color). Kept as plain label lists
  /// rather than a richer variant-pricing model since price doesn't
  /// change per variant in this catalog yet.
  final List<String> _sizes;

  /// Selectable variants — empty when the product doesn't have that axis
  /// (e.g. a bag of cement has no size/color). Kept as plain label lists
  /// rather than a richer variant-pricing model since price doesn't
  /// change per variant in this catalog yet.
  @override
  @JsonKey()
  List<String> get sizes {
    if (_sizes is EqualUnmodifiableListView) return _sizes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sizes);
  }

  final List<String> _colors;
  @override
  @JsonKey()
  List<String> get colors {
    if (_colors is EqualUnmodifiableListView) return _colors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_colors);
  }

  /// Where the product is manufactured/sourced from — defaults to Mali
  /// since most of the seeded catalog is local artisanal/agricultural
  /// goods; imported categories (electronics, some materials) override it.
  @override
  @JsonKey()
  final ProductRegion region;

  /// Lifecycle within the supplier's own catalog management — see
  /// `ProductStatus`'s doc comment. Defaults to `active` so every
  /// pre-existing seeded product (created before this field existed)
  /// stays visible without a data migration.
  @override
  @JsonKey()
  final ProductStatus status;

  /// Below this stock level, the supplier's product list flags the item
  /// as low — `null` means no threshold is set (no warning is ever
  /// shown). A per-product setting rather than a platform-wide constant
  /// since restock lead time varies a lot by category (e.g. imported
  /// electronics vs. locally-milled rice).
  @override
  final int? lowStockThreshold;

  /// The pre-discount price, shown struck through next to [priceFcfa]
  /// when set and higher than it — a plain "barré" price, not a
  /// scheduled/rule-based promotion engine.
  @override
  final int? compareAtPriceFcfa;

  /// Bumped by [ProductRepository.incrementViewCount] once per client
  /// visit to the product's detail page — shown on the supplier
  /// dashboard, not client-facing anywhere.
  @override
  @JsonKey()
  final int viewCount;

  /// Trigger-maintained (`0018_product_variants.sql`) — the only
  /// reliable "does this product have variants" signal, true even from
  /// list queries (`watchProducts`/`watchMyProducts`) that don't embed
  /// [characteristics]/[variants] below. Never infer this from
  /// `characteristics.isEmpty`/`variants.isEmpty`: those are only
  /// populated by `getById`'s nested select.
  @override
  @JsonKey()
  final bool hasVariants;

  /// Trigger-maintained max variant price — `null` unless [hasVariants].
  /// Paired with [priceFcfa] (trigger-maintained min variant price once
  /// variants exist) to render "à partir de" range pricing without
  /// fetching [variants].
  @override
  final int? maxPriceFcfa;

  /// Trigger-maintained count of this product's variants — `0` unless
  /// [hasVariants]. Lets list views show "N variantes" without embedding
  /// the full [variants] list.
  @override
  @JsonKey()
  final int variantCount;

  /// This product's characteristics (couleur/stockage/...), each with its
  /// own options — only populated via `getById`'s nested select (product
  /// detail, cart line, checkout, favorites resolve, chat attachment,
  /// stock-adjust sheet). Always empty from list queries.
  final List<ProductCharacteristic> _characteristics;

  /// This product's characteristics (couleur/stockage/...), each with its
  /// own options — only populated via `getById`'s nested select (product
  /// detail, cart line, checkout, favorites resolve, chat attachment,
  /// stock-adjust sheet). Always empty from list queries.
  @override
  @JsonKey()
  List<ProductCharacteristic> get characteristics {
    if (_characteristics is EqualUnmodifiableListView) return _characteristics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_characteristics);
  }

  /// This product's purchasable variants — same nested-select-only
  /// population as [characteristics].
  final List<ProductVariant> _variants;

  /// This product's purchasable variants — same nested-select-only
  /// population as [characteristics].
  @override
  @JsonKey()
  List<ProductVariant> get variants {
    if (_variants is EqualUnmodifiableListView) return _variants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_variants);
  }

  @override
  String toString() {
    return 'Product(id: $id, supplierId: $supplierId, supplierName: $supplierName, supplierType: $supplierType, name: $name, description: $description, category: $category, priceFcfa: $priceFcfa, stockQuantity: $stockQuantity, imageUrls: $imageUrls, city: $city, ratingAverage: $ratingAverage, ratingCount: $ratingCount, allowsSelfDelivery: $allowsSelfDelivery, allowsMtcDelivery: $allowsMtcDelivery, createdAt: $createdAt, weightKg: $weightKg, isSupplierVerified: $isSupplierVerified, sizes: $sizes, colors: $colors, region: $region, status: $status, lowStockThreshold: $lowStockThreshold, compareAtPriceFcfa: $compareAtPriceFcfa, viewCount: $viewCount, hasVariants: $hasVariants, maxPriceFcfa: $maxPriceFcfa, variantCount: $variantCount, characteristics: $characteristics, variants: $variants)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ProductImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.supplierId, supplierId) ||
                other.supplierId == supplierId) &&
            (identical(other.supplierName, supplierName) ||
                other.supplierName == supplierName) &&
            (identical(other.supplierType, supplierType) ||
                other.supplierType == supplierType) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.priceFcfa, priceFcfa) ||
                other.priceFcfa == priceFcfa) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            const DeepCollectionEquality().equals(
              other._imageUrls,
              _imageUrls,
            ) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.ratingAverage, ratingAverage) ||
                other.ratingAverage == ratingAverage) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.allowsSelfDelivery, allowsSelfDelivery) ||
                other.allowsSelfDelivery == allowsSelfDelivery) &&
            (identical(other.allowsMtcDelivery, allowsMtcDelivery) ||
                other.allowsMtcDelivery == allowsMtcDelivery) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.weightKg, weightKg) ||
                other.weightKg == weightKg) &&
            (identical(other.isSupplierVerified, isSupplierVerified) ||
                other.isSupplierVerified == isSupplierVerified) &&
            const DeepCollectionEquality().equals(other._sizes, _sizes) &&
            const DeepCollectionEquality().equals(other._colors, _colors) &&
            (identical(other.region, region) || other.region == region) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.lowStockThreshold, lowStockThreshold) ||
                other.lowStockThreshold == lowStockThreshold) &&
            (identical(other.compareAtPriceFcfa, compareAtPriceFcfa) ||
                other.compareAtPriceFcfa == compareAtPriceFcfa) &&
            (identical(other.viewCount, viewCount) ||
                other.viewCount == viewCount) &&
            (identical(other.hasVariants, hasVariants) ||
                other.hasVariants == hasVariants) &&
            (identical(other.maxPriceFcfa, maxPriceFcfa) ||
                other.maxPriceFcfa == maxPriceFcfa) &&
            (identical(other.variantCount, variantCount) ||
                other.variantCount == variantCount) &&
            const DeepCollectionEquality().equals(
              other._characteristics,
              _characteristics,
            ) &&
            const DeepCollectionEquality().equals(other._variants, _variants));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    supplierId,
    supplierName,
    supplierType,
    name,
    description,
    category,
    priceFcfa,
    stockQuantity,
    const DeepCollectionEquality().hash(_imageUrls),
    city,
    ratingAverage,
    ratingCount,
    allowsSelfDelivery,
    allowsMtcDelivery,
    createdAt,
    weightKg,
    isSupplierVerified,
    const DeepCollectionEquality().hash(_sizes),
    const DeepCollectionEquality().hash(_colors),
    region,
    status,
    lowStockThreshold,
    compareAtPriceFcfa,
    viewCount,
    hasVariants,
    maxPriceFcfa,
    variantCount,
    const DeepCollectionEquality().hash(_characteristics),
    const DeepCollectionEquality().hash(_variants),
  ]);

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      __$$ProductImplCopyWithImpl<_$ProductImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ProductImplToJson(this);
  }
}

abstract class _Product implements Product {
  const factory _Product({
    required final String id,
    required final String supplierId,
    required final String supplierName,
    required final SupplierType supplierType,
    required final String name,
    required final String description,
    required final ProductCategory category,
    required final int priceFcfa,
    required final int stockQuantity,
    required final List<String> imageUrls,
    required final String city,
    required final double ratingAverage,
    required final int ratingCount,
    required final bool allowsSelfDelivery,
    required final bool allowsMtcDelivery,
    required final DateTime createdAt,
    required final double weightKg,
    final bool isSupplierVerified,
    final List<String> sizes,
    final List<String> colors,
    final ProductRegion region,
    final ProductStatus status,
    final int? lowStockThreshold,
    final int? compareAtPriceFcfa,
    final int viewCount,
    final bool hasVariants,
    final int? maxPriceFcfa,
    final int variantCount,
    final List<ProductCharacteristic> characteristics,
    final List<ProductVariant> variants,
  }) = _$ProductImpl;

  factory _Product.fromJson(Map<String, dynamic> json) = _$ProductImpl.fromJson;

  @override
  String get id;
  @override
  String get supplierId;
  @override
  String get supplierName;
  @override
  SupplierType get supplierType;
  @override
  String get name;
  @override
  String get description;
  @override
  ProductCategory get category;
  @override
  int get priceFcfa;
  @override
  int get stockQuantity;
  @override
  List<String> get imageUrls;
  @override
  String get city;
  @override
  double get ratingAverage;
  @override
  int get ratingCount;
  @override
  bool get allowsSelfDelivery;
  @override
  bool get allowsMtcDelivery;
  @override
  DateTime get createdAt;

  /// Shipping weight — feeds `computeHomeDeliveryFeeFcfa`
  /// (features/orders/domain/delivery_pricing.dart) alongside distance and
  /// category, so heavier items cost more to have MTC deliver. No longer
  /// a flat per-product fee: that's computed per order, per destination.
  @override
  double get weightKg;

  /// Denormalized from the supplier's verification status. Products from
  /// unverified/pending tiers suppliers are excluded from client-facing
  /// catalog queries — visibility on the platform is earned through
  /// verification + rating, per the product's trust model.
  @override
  bool get isSupplierVerified;

  /// Selectable variants — empty when the product doesn't have that axis
  /// (e.g. a bag of cement has no size/color). Kept as plain label lists
  /// rather than a richer variant-pricing model since price doesn't
  /// change per variant in this catalog yet.
  @override
  List<String> get sizes;
  @override
  List<String> get colors;

  /// Where the product is manufactured/sourced from — defaults to Mali
  /// since most of the seeded catalog is local artisanal/agricultural
  /// goods; imported categories (electronics, some materials) override it.
  @override
  ProductRegion get region;

  /// Lifecycle within the supplier's own catalog management — see
  /// `ProductStatus`'s doc comment. Defaults to `active` so every
  /// pre-existing seeded product (created before this field existed)
  /// stays visible without a data migration.
  @override
  ProductStatus get status;

  /// Below this stock level, the supplier's product list flags the item
  /// as low — `null` means no threshold is set (no warning is ever
  /// shown). A per-product setting rather than a platform-wide constant
  /// since restock lead time varies a lot by category (e.g. imported
  /// electronics vs. locally-milled rice).
  @override
  int? get lowStockThreshold;

  /// The pre-discount price, shown struck through next to [priceFcfa]
  /// when set and higher than it — a plain "barré" price, not a
  /// scheduled/rule-based promotion engine.
  @override
  int? get compareAtPriceFcfa;

  /// Bumped by [ProductRepository.incrementViewCount] once per client
  /// visit to the product's detail page — shown on the supplier
  /// dashboard, not client-facing anywhere.
  @override
  int get viewCount;

  /// Trigger-maintained (`0018_product_variants.sql`) — the only
  /// reliable "does this product have variants" signal, true even from
  /// list queries (`watchProducts`/`watchMyProducts`) that don't embed
  /// [characteristics]/[variants] below. Never infer this from
  /// `characteristics.isEmpty`/`variants.isEmpty`: those are only
  /// populated by `getById`'s nested select.
  @override
  bool get hasVariants;

  /// Trigger-maintained max variant price — `null` unless [hasVariants].
  /// Paired with [priceFcfa] (trigger-maintained min variant price once
  /// variants exist) to render "à partir de" range pricing without
  /// fetching [variants].
  @override
  int? get maxPriceFcfa;

  /// Trigger-maintained count of this product's variants — `0` unless
  /// [hasVariants]. Lets list views show "N variantes" without embedding
  /// the full [variants] list.
  @override
  int get variantCount;

  /// This product's characteristics (couleur/stockage/...), each with its
  /// own options — only populated via `getById`'s nested select (product
  /// detail, cart line, checkout, favorites resolve, chat attachment,
  /// stock-adjust sheet). Always empty from list queries.
  @override
  List<ProductCharacteristic> get characteristics;

  /// This product's purchasable variants — same nested-select-only
  /// population as [characteristics].
  @override
  List<ProductVariant> get variants;

  /// Create a copy of Product
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ProductImplCopyWith<_$ProductImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
