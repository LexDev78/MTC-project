import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_status.dart';
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
    final row = await _datasource.add(product.toJson());
    return Product.fromJson(row);
  }

  @override
  Future<void> updateProduct(Product product) {
    final fields = product.toJson()
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
    String? note,
  }) {
    return _datasource.adjustStock(
      id: id,
      quantityDelta: quantityDelta,
      reason: _stockReasonToDb(reason),
      note: note,
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
}

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
