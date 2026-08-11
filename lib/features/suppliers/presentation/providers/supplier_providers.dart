import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/in_memory_supplier_datasource.dart';
import '../../data/repositories/in_memory_supplier_repository.dart';
import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';

final supplierDatasourceProvider = Provider<InMemorySupplierDatasource>((ref) {
  return InMemorySupplierDatasource();
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return InMemorySupplierRepository(ref.watch(supplierDatasourceProvider));
});

final supplierDetailProvider = FutureProvider.family<SupplierProfile, String>((
  ref,
  id,
) {
  return ref.watch(supplierRepositoryProvider).getById(id);
});
