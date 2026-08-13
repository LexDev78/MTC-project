import '../entities/product_comment.dart';

abstract interface class ProductCommentRepository {
  Stream<List<ProductComment>> watchForProduct(String productId);

  /// Every comment (top-level and replies) across every one of
  /// [supplierId]'s products — feeds the supplier's comment inbox.
  Stream<List<ProductComment>> watchForSupplier(String supplierId);

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
  });

  Future<void> toggleLike({required String commentId, required String userId});
}
