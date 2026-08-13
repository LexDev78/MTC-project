import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_supplier_kyc_datasource.dart';
import '../../data/repositories/supabase_supplier_kyc_repository.dart';
import '../../domain/entities/supplier_kyc.dart';
import '../../domain/repositories/supplier_kyc_repository.dart';

final supplierKycDatasourceProvider = Provider<SupabaseSupplierKycDatasource>((
  ref,
) {
  return SupabaseSupplierKycDatasource(ref.watch(supabaseClientProvider));
});

final supplierKycRepositoryProvider = Provider<SupplierKycRepository>((ref) {
  return SupabaseSupplierKycRepository(ref.watch(supplierKycDatasourceProvider));
});

/// The signed-in supplier's own dossier — `null` until their first draft
/// save (fresh `unverified` accounts land here with nothing yet).
final myKycProvider = StreamProvider.family<SupplierKyc?, String>((
  ref,
  supplierId,
) {
  return ref.watch(supplierKycRepositoryProvider).watchForSupplier(supplierId);
});

/// Staff review queue: everything waiting on a decision.
final kycReviewQueueProvider = StreamProvider<List<SupplierKyc>>((ref) {
  return ref.watch(supplierKycRepositoryProvider).watchQueue();
});
