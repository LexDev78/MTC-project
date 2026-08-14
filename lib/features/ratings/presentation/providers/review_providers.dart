import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_review_datasource.dart';
import '../../data/repositories/supabase_review_repository.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

final reviewDatasourceProvider = Provider<SupabaseReviewDatasource>((ref) {
  return SupabaseReviewDatasource(ref.watch(supabaseClientProvider));
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository(ref.watch(reviewDatasourceProvider));
});

final supplierReviewsProvider = StreamProvider.family<List<Review>, String>((
  ref,
  supplierId,
) {
  return ref.watch(reviewRepositoryProvider).watchForSupplier(supplierId);
});

typedef ReviewKey = ({String orderId, String groupId});

final canReviewProvider = FutureProvider.family<bool, ReviewKey>((ref, key) {
  return ref
      .watch(reviewRepositoryProvider)
      .canReview(orderId: key.orderId, supplierGroupId: key.groupId);
});
