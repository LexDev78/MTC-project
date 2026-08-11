import 'package:mtc_app/features/catalog/domain/entities/product_category.dart'
    show SupplierType;

import '../entities/supplier_profile.dart';

abstract interface class SupplierRepository {
  Stream<List<SupplierProfile>> watchByType(SupplierType type);

  Future<SupplierProfile> getById(String id);

  Stream<List<SupplierProfile>> watchTopRated({int limit = 5});

  /// Folds a new review's [stars] into the supplier's running rating
  /// average (`(oldAverage * oldCount + stars) / (oldCount + 1)`) and
  /// returns the updated aggregate, so callers can propagate it to
  /// wherever else a supplier's rating is denormalized (e.g. `Product`).
  Future<({double average, int count})> recordReview({
    required String supplierId,
    required int stars,
  });
}
