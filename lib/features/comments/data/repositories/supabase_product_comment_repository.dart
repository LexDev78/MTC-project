import '../../domain/entities/product_comment.dart';
import '../../domain/repositories/product_comment_repository.dart';
import '../datasources/supabase_product_comment_datasource.dart';

class SupabaseProductCommentRepository implements ProductCommentRepository {
  SupabaseProductCommentRepository(this._datasource);

  final SupabaseProductCommentDatasource _datasource;

  @override
  Stream<List<ProductComment>> watchForProduct(String productId) {
    return _datasource
        .watchForProduct(productId)
        .map((rows) => rows.map(ProductComment.fromJson).toList());
  }

  @override
  Stream<List<ProductComment>> watchForSupplier(String supplierId) {
    return _datasource
        .watchForSupplier(supplierId)
        .map((rows) => rows.map(ProductComment.fromJson).toList());
  }

  @override
  Future<void> addComment({
    required String productId,
    required String supplierId,
    required String authorId,
    required String authorName,
    required bool isSupplier,
    required String text,
    String? parentId,
    CommentAttachmentType attachmentType = CommentAttachmentType.none,
    String? attachmentPath,
    int? voiceDurationSeconds,
  }) {
    return _datasource.addComment({
      'product_id': productId,
      'supplier_id': supplierId,
      'author_id': authorId,
      'author_name': authorName,
      'is_supplier': isSupplier,
      'text': text,
      'parent_id': parentId,
      'attachment_type': attachmentType.name,
      'attachment_path': attachmentPath,
      'voice_duration_seconds': voiceDurationSeconds,
    });
  }

  @override
  Future<void> toggleLike({required String commentId, required String userId}) {
    return _datasource.toggleLike(commentId: commentId, userId: userId);
  }
}
