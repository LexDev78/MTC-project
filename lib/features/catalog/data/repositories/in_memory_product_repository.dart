import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
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
        if (supplierType != null && p.supplierType != supplierType) {
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
}
