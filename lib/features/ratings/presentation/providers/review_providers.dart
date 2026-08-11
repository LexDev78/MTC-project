import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/in_memory_review_datasource.dart';
import '../../data/repositories/in_memory_review_repository.dart';
import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart';

final reviewDatasourceProvider = Provider<InMemoryReviewDatasource>((ref) {
  return InMemoryReviewDatasource();
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return InMemoryReviewRepository(ref.watch(reviewDatasourceProvider));
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
