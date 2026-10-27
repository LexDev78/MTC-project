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

/// `autoDispose`: the underlying datasource only re-emits after a write made
/// through this same client instance (see its doc comment — no Realtime),
/// so a comment/reply posted from someone else's session never reaches an
/// already-open screen on its own. Disposing once nothing watches it means
/// leaving and coming back re-subscribes and pulls whatever's actually in
/// the database, instead of replaying a stale snapshot (in the worst case,
/// one taken before any comments existed at all) for the rest of the app
/// session.
final productCommentsProvider =
    StreamProvider.autoDispose.family<List<ProductComment>, String>((
      ref,
      productId,
    ) {
      return ref
          .watch(productCommentRepositoryProvider)
          .watchForProduct(productId);
    });

/// Every comment across every one of [supplierId]'s products — feeds the
/// supplier's comment inbox (see `SupplierCommentInboxScreen`). Same
/// `autoDispose` reasoning as [productCommentsProvider].
final supplierProductCommentsProvider =
    StreamProvider.autoDispose.family<List<ProductComment>, String>((
      ref,
      supplierId,
    ) {
      return ref
          .watch(productCommentRepositoryProvider)
          .watchForSupplier(supplierId);
    });
