import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

import '../../data/datasources/supabase_product_comment_datasource.dart';
import '../../data/repositories/supabase_product_comment_repository.dart';
import '../../domain/entities/product_comment.dart';
import '../../domain/repositories/product_comment_repository.dart';

final productCommentDatasourceProvider =
    Provider<SupabaseProductCommentDatasource>((ref) {
      return SupabaseProductCommentDatasource(ref.watch(supabaseClientProvider));
    });

final productCommentRepositoryProvider = Provider<ProductCommentRepository>((
  ref,
) {
  return SupabaseProductCommentRepository(
    ref.watch(productCommentDatasourceProvider),
  );
});

final productCommentsProvider =
    StreamProvider.family<List<ProductComment>, String>((ref, productId) {
      return ref
          .watch(productCommentRepositoryProvider)
          .watchForProduct(productId);
    });

/// Every comment across every one of [supplierId]'s products — feeds the
/// supplier's comment inbox (see `SupplierCommentInboxScreen`).
final supplierProductCommentsProvider =
    StreamProvider.family<List<ProductComment>, String>((ref, supplierId) {
      return ref
          .watch(productCommentRepositoryProvider)
          .watchForSupplier(supplierId);
    });
