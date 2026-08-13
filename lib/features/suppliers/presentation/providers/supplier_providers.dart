import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_supplier_datasource.dart';
import '../../data/repositories/supabase_supplier_repository.dart';
import '../../domain/entities/supplier_profile.dart';
import '../../domain/repositories/supplier_repository.dart';

final supplierDatasourceProvider = Provider<SupabaseSupplierDatasource>((ref) {
  return SupabaseSupplierDatasource(ref.watch(supabaseClientProvider));
});

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  return SupabaseSupplierRepository(ref.watch(supplierDatasourceProvider));
});

final supplierDetailProvider = FutureProvider.family<SupplierProfile, String>((
  ref,
  id,
) {
  return ref.watch(supplierRepositoryProvider).getById(id);
});
