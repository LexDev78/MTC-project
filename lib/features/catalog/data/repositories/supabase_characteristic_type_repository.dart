import '../../domain/entities/product_characteristic_type.dart';
import '../../domain/repositories/characteristic_type_repository.dart';
import '../datasources/supabase_characteristic_type_datasource.dart';

class SupabaseCharacteristicTypeRepository
    implements CharacteristicTypeRepository {
  SupabaseCharacteristicTypeRepository(this._datasource);

  final SupabaseCharacteristicTypeDatasource _datasource;

  @override
  Stream<List<ProductCharacteristicType>> watchApprovedTypes() {
    return _datasource
        .watchApproved()
        .map((rows) => rows.map(ProductCharacteristicType.fromJson).toList());
  }

  @override
  Stream<List<ProductCharacteristicType>> watchQueue() {
    return _datasource
        .watchQueue()
        .map((rows) => rows.map(ProductCharacteristicType.fromJson).toList());
  }

  @override
  Future<void> propose({required String supplierId, required String label}) {
    return _datasource.propose(supplierId: supplierId, label: label);
  }

  @override
  Future<void> review({
    required String id,
    required bool approve,
    String? reason,
  }) {
    return _datasource.review(id: id, approve: approve, reason: reason);
  }
}
