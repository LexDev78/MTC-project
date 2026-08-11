import '../entities/product.dart';
import '../entities/product_category.dart';

abstract interface class ProductRepository {
  Stream<List<Product>> watchProducts({
    SupplierType? supplierType,
    ProductCategory? category,
    String? query,
    String? supplierId,
  });

  Future<Product> getById(String id);

  /// Propagates a supplier's newly recomputed rating to every one of their
  /// products — `Product.ratingAverage/ratingCount` is a denormalized copy
  /// (so catalog sorting/filtering never needs a supplier join), and a
  /// review only updates the supplier record directly.
  Future<void> updateSupplierRating({
    required String supplierId,
    required double ratingAverage,
    required int ratingCount,
  });
}
