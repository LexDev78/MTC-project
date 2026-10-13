import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_pricing.dart';
import '../../domain/entities/promotion.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/supabase_product_datasource.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this._datasource);

  final SupabaseProductDatasource _datasource;

  @override
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  }) {
    return _datasource
        .watchProducts(
          supplierType: supplierType?.name,
          category: category,
          query: query,
          supplierId: supplierId,
        )
        .map((rows) => rows.map(Product.fromJson).toList());
  }

  @override
  Future<Product> getById(String id) async {
    return Product.fromJson(await _datasource.getById(id));
  }

  @override
  Future<List<Product>> fetchByIds(List<String> ids) async {
    final rows = await _datasource.fetchByIds(ids);
    // Indexé puis relu dans l'ordre de [ids] : la base rend les lignes dans
    // l'ordre qui l'arrange, alors que le classement est précisément ce que
    // l'appelant veut préserver. Les identifiants sans ligne correspondante
    // (produit devenu invisible) tombent d'eux-mêmes.
    final byId = {for (final row in rows) row['id'] as String: row};
    return [
      for (final id in ids)
        if (byId[id] case final row?) Product.fromJson(row),
    ];
  }

  @override
  Future<void> updateSupplierRating({
    required String supplierId,
    required double ratingAverage,
    required int ratingCount,
  }) {
    return _datasource.updateSupplierRating(
      supplierId: supplierId,
      ratingAverage: ratingAverage,
      ratingCount: ratingCount,
    );
  }

  @override
  Stream<List<Product>> watchMyProducts(String supplierId) {
    return _datasource
        .watchMyProducts(supplierId)
        .map((rows) => rows.map(Product.fromJson).toList());
  }

  @override
  Future<Product> createProduct({
    required String supplierId,
    required String supplierName,
    required SupplierType supplierType,
    required bool isSupplierVerified,
    required String name,
    required String description,
    required ProductCategory category,
    required int priceFcfa,
    required int stockQuantity,
    required double weightKg,
    required String city,
    required List<String> imageUrls,
    required bool allowsSelfDelivery,
    required bool allowsMtcDelivery,
    required List<String> sizes,
    required List<String> colors,
    required ProductRegion region,
    int? lowStockThreshold,
    int? compareAtPriceFcfa,
  }) async {
    final product = Product(
      id: IdGenerator.next(),
      supplierId: supplierId,
      supplierName: supplierName,
      supplierType: supplierType,
      isSupplierVerified: isSupplierVerified,
      name: name,
      description: description,
      category: category,
      priceFcfa: priceFcfa,
      stockQuantity: stockQuantity,
      imageUrls: imageUrls,
      city: city,
      ratingAverage: 0,
      ratingCount: 0,
      allowsSelfDelivery: allowsSelfDelivery,
      allowsMtcDelivery: allowsMtcDelivery,
      weightKg: weightKg,
      createdAt: DateTime.now(),
      sizes: sizes,
      colors: colors,
      region: region,
      status: ProductStatus.draft,
      lowStockThreshold: lowStockThreshold,
      compareAtPriceFcfa: compareAtPriceFcfa,
    );
    final row = await _datasource.add(_stripComputedFields(product.toJson()));
    return Product.fromJson(row);
  }

  @override
  Future<void> updateProduct(Product product) {
    final fields = _stripComputedFields(product.toJson())
      ..remove('id')
      ..remove('created_at');
    return _datasource.update(product.id, fields);
  }

  @override
  Future<void> setStatus({required String id, required ProductStatus status}) {
    return _datasource.setStatus(id, status.name);
  }

  @override
  Future<void> adjustStock({
    required String id,
    required int quantityDelta,
    required StockMovementReason reason,
    String? variantId,
    String? note,
  }) {
    return _datasource.adjustStock(
      id: id,
      quantityDelta: quantityDelta,
      reason: _stockReasonToDb(reason),
      variantId: variantId,
      note: note,
    );
  }

  @override
  Future<void> replaceCharacteristicsAndVariants({
    required String productId,
    required List<ProductCharacteristic> characteristics,
    required List<ProductVariant> variants,
  }) {
    return _datasource.replaceCharacteristicsAndVariants(
      productId: productId,
      characteristics: [
        for (final c in characteristics)
          {
            'id': c.id,
            'type_id': c.type.id,
            'display_order': c.displayOrder,
            'options': [
              for (final o in c.options)
                {
                  'id': o.id,
                  'value': o.value,
                  'price_delta_fcfa': o.priceDeltaFcfa,
                  'display_order': o.displayOrder,
                },
            ],
          },
      ],
      variants: [
        for (final v in variants)
          {
            'id': v.id,
            'name': v.name,
            'price_fcfa': v.priceFcfa,
            'stock_quantity': v.stockQuantity,
            'image_urls': v.imageUrls,
            'video_path': v.videoPath,
            'is_default': v.isDefault,
            'display_order': v.displayOrder,
            'option_refs': [
              for (final r in v.optionRefs)
                {'characteristic_id': r.characteristicId, 'option_id': r.optionId},
            ],
          },
      ],
    );
  }

  @override
  Stream<List<StockMovement>> watchStockMovements(String productId) {
    return _datasource
        .watchStockMovements(productId)
        .map((rows) => rows.map(StockMovement.fromJson).toList());
  }

  @override
  Future<void> updateSupplierVerification({
    required String supplierId,
    required bool isVerified,
  }) {
    return _datasource.updateSupplierVerification(
      supplierId: supplierId,
      isVerified: isVerified,
    );
  }

  @override
  Future<void> incrementViewCount(String productId) {
    return _datasource.incrementViewCount(productId);
  }

  @override
  Future<Map<String, ProductStats>> fetchProductStats(String supplierId) async {
    final rows = await _datasource.fetchSupplierProductStats(supplierId);
    return {
      for (final row in rows)
        // `count(*)` comes back as Postgres `bigint` — `num`, not
        // guaranteed `int`, depending on how it round-trips through JSON.
        row['product_id'] as String: (
          favoriteCount: (row['favorite_count'] as num).toInt(),
          orderCount: (row['order_count'] as num).toInt(),
        ),
    };
  }

  @override
  Future<Map<String, ProductPricing>> fetchPricing(
    List<String> productIds,
  ) async {
    final rows = await _datasource.fetchPricingInputs(productIds);
    return {
      for (final entry in rows.entries)
        entry.key: _pricingFromJson(entry.value as Map<String, dynamic>),
    };
  }

  @override
  Future<void> createPromotion({
    required String productId,
    required PromotionKind kind,
    required int value,
    int minQuantity = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    String? label,
  }) {
    return _datasource.addPromotion({
      'product_id': productId,
      'kind': switch (kind) {
        PromotionKind.percentage => 'percentage',
        PromotionKind.fixedAmount => 'fixed_amount',
      },
      'value': value,
      'min_quantity': minQuantity,
      // `toUtc()` avant de sérialiser : `toIso8601String()` sur une date
      // locale ne porte aucun décalage, et Postgres lit alors la valeur
      // comme de l'UTC. La fenêtre d'une promotion se déplacerait du
      // décalage de l'appareil — invisible au Mali (UTC+0 toute l'année),
      // faux partout ailleurs, y compris sur la machine qui exécute les
      // tests.
      'starts_at': startsAt?.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'label': label,
    });
  }

  @override
  Future<void> setPromotionActive({
    required String id,
    required bool isActive,
  }) {
    return _datasource.updatePromotion(id, {'is_active': isActive});
  }

  @override
  Future<void> deletePromotion(String id) => _datasource.deletePromotion(id);
}

/// `Product.toJson()` includes 6 keys that don't belong in a
/// create/update payload to `products` :
/// [characteristics]/[variants]/[promotions] are relationship data from the
/// nested selects, not real columns at all — sending them makes PostgREST
/// reject the whole request. `has_variants`/`max_price_fcfa`/`variant_count`
/// ARE real columns, but they're exclusively trigger-maintained
/// (`0018_product_variants.sql`) — writing whatever value happened to be on
/// the in-memory [Product] risks clobbering a fresher aggregate with a stale
/// one if a variant's stock/price changed between this product being fetched
/// and this write.
///
/// Les promotions ont rejoint cette liste avec `0062` : elles arrivent
/// désormais dans **toutes** les lectures de produit, listes comprises, donc
/// elles repartaient dans chaque écriture. L'erreur était claire
/// (« Could not find the 'promotions' column ») mais elle tombait sur les
/// écritures de produit, loin de la promotion qu'on venait d'ajouter.
Map<String, dynamic> _stripComputedFields(Map<String, dynamic> fields) => fields
  ..remove('characteristics')
  ..remove('variants')
  ..remove('promotions')
  ..remove('has_variants')
  ..remove('max_price_fcfa')
  ..remove('variant_count');

/// `StockMovementReason.manualAdjustment`'s `@JsonValue` lives on the enum
/// itself (`stock_movement.dart`, Lot 2) but that mapping is only reachable
/// through a full `StockMovement.toJson()` — this datasource only ever
/// sends the bare `reason` column, so it needs the same mapping standalone.
String _stockReasonToDb(StockMovementReason reason) => switch (reason) {
  StockMovementReason.manualAdjustment => 'manual_adjustment',
  StockMovementReason.sale => 'sale',
  StockMovementReason.restock => 'restock',
  StockMovementReason.returned => 'returned',
  StockMovementReason.correction => 'correction',
};

/// Assemblage à la main de `fetch_pricing_inputs` (`0068`) : les variantes
/// y sont une table indexée par identifiant, ce que `json_serializable` ne
/// produit pas naturellement, et la promotion a déjà son `fromJson`.
ProductPricing _pricingFromJson(Map<String, dynamic> json) {
  return ProductPricing(
    priceFcfa: (json['price_fcfa'] as num).toInt(),
    stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
    category: categoryFromDb(json['category'] as String),
    city: json['city'] as String? ?? '',
    supplierId: json['supplier_id'] as String,
    supplierName: json['supplier_name'] as String? ?? '',
    allowsSelfDelivery: json['allows_self_delivery'] as bool? ?? true,
    allowsMtcDelivery: json['allows_mtc_delivery'] as bool? ?? true,
    variants: {
      for (final entry in (json['variants'] as Map).entries)
        entry.key as String: VariantPricing(
          priceFcfa: ((entry.value as Map)['price_fcfa'] as num).toInt(),
          stockQuantity:
              ((entry.value as Map)['stock_quantity'] as num?)?.toInt() ?? 0,
        ),
    },
    promotions: [
      for (final row in (json['promotions'] as List))
        Promotion.fromJson(Map<String, dynamic>.from(row as Map)),
    ],
  );
}
