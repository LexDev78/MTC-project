import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_status.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/in_memory_product_datasource.dart';

class InMemoryProductRepository implements ProductRepository {
  InMemoryProductRepository(this._datasource);

  final InMemoryProductDatasource _datasource;

  @override
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  }) {
    return _datasource.watchAll().map((products) {
      final normalizedQuery = query?.trim().toLowerCase();

      final filtered = products.where((p) {
        // Verification gates visibility: unverified/pending tiers suppliers
        // never appear in a client-facing catalog query.
        if (!p.isSupplierVerified) return false;
        // Draft/paused/archived listings are the supplier's own concern —
        // only `watchMyProducts` ever shows them.
        if (p.status != ProductStatus.active) return false;
        // The "principal" tab is the aggregated MTC catalog: it shows every
        // verified product, including third-party ones, without changing
        // that product's actual supplier attribution. Only the "tiers" tab
        // stays restricted to third-party products.
        if (supplierType == SupplierType.tiers &&
            p.supplierType != SupplierType.tiers) {
          return false;
        }
        if (category != null && p.category != category) return false;
        if (supplierId != null && p.supplierId != supplierId) return false;
        if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
          final haystack = '${p.name} ${p.description} ${p.supplierName}'
              .toLowerCase();
          if (!haystack.contains(normalizedQuery)) return false;
        }
        return true;
      }).toList();

      // Higher-rated suppliers surface first — visibility on the platform
      // is earned through client ratings.
      filtered.sort((a, b) {
        final ratingCompare = b.ratingAverage.compareTo(a.ratingAverage);
        if (ratingCompare != 0) return ratingCompare;
        return a.name.compareTo(b.name);
      });

      return filtered;
    });
  }

  @override
  Future<Product> getById(String id) async => _datasource.getById(id);

  @override
  Future<void> updateSupplierRating({
    required String supplierId,
    required double ratingAverage,
    required int ratingCount,
  }) async {
    _datasource.updateSupplierRating(supplierId, ratingAverage, ratingCount);
  }

  @override
  Stream<List<Product>> watchMyProducts(String supplierId) {
    return _datasource.watchAll().map(
      (_) => _datasource.watchMyProducts(supplierId),
    );
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
    return _datasource.add(
      Product(
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
      ),
    );
  }

  @override
  Future<void> updateProduct(Product product) async {
    _datasource.update(product);
  }

  @override
  Future<void> setStatus({
    required String id,
    required ProductStatus status,
  }) async {
    _datasource.setStatus(id, status);
  }

  @override
  Future<void> adjustStock({
    required String id,
    required int quantityDelta,
    required StockMovementReason reason,
    String? note,
  }) async {
    _datasource.adjustStock(id, quantityDelta, reason, note);
  }

  @override
  Stream<List<StockMovement>> watchStockMovements(String productId) {
    return _datasource.watchStockMovements(productId);
  }

  @override
  Future<void> updateSupplierVerification({
    required String supplierId,
    required bool isVerified,
  }) async {
    _datasource.updateSupplierVerification(supplierId, isVerified);
  }
}
