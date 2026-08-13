import 'package:mtc_app/features/auth/domain/entities/user_role.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_category.dart';

import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../datasources/in_memory_supplier_datasource.dart';

class InMemorySupplierRepository implements SupplierRepository {
  InMemorySupplierRepository(this._datasource);

  final InMemorySupplierDatasource _datasource;

  @override
  Future<SupplierProfile> createProfile({
    required String id,
    required String businessName,
    required SupplierType supplierType,
    required String city,
    required SupplierLegalType legalType,
  }) async {
    return _datasource.add(
      SupplierProfile(
        id: id,
        businessName: businessName,
        supplierType: supplierType,
        city: city,
        ratingAverage: 0,
        ratingCount: 0,
        productCount: 0,
        verificationStatus: VerificationStatus.unverified,
        legalType: legalType,
      ),
    );
  }

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
              .where(
                (s) =>
                    s.verificationStatus == null ||
                    s.verificationStatus == VerificationStatus.verified,
              )
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

  @override
  Future<void> updateVerificationStatus({
    required String supplierId,
    required VerificationStatus status,
  }) async {
    _datasource.updateVerificationStatus(supplierId, status);
  }

  @override
  Future<void> adjustProductCount({
    required String supplierId,
    required int delta,
  }) async {
    _datasource.adjustProductCount(supplierId, delta);
  }
}
