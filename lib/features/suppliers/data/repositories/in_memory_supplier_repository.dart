import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/in_memory_supplier_datasource.dart';

class InMemorySupplierRepository implements SupplierRepository {
  InMemorySupplierRepository(this._datasource);

  final InMemorySupplierDatasource _datasource;

  @override
  Stream<List<SupplierProfile>> watchByType(SupplierType type) {
    return _datasource.watchAll().map(
      (suppliers) => suppliers.where((s) => s.supplierType == type).toList(),
    );
  }

  @override
  Future<SupplierProfile> getById(String id) async => _datasource.getById(id);

  @override
  Stream<List<SupplierProfile>> watchTopRated({int limit = 5}) {
    return _datasource.watchAll().map((suppliers) {
      final visible =
          suppliers
              .where((s) => s.verificationStatus != VerificationStatus.pending)
              .where((s) => s.verificationStatus != VerificationStatus.rejected)
              .toList()
            ..sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
      return visible.take(limit).toList();
    });
  }

  @override
  Future<({double average, int count})> recordReview({
    required String supplierId,
    required int stars,
  }) async {
    return _datasource.recordReview(supplierId, stars);
  }
}
