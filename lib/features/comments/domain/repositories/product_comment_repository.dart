import '../entities/product_comment.dart';

abstract interface class ProductCommentRepository {
  Stream<List<ProductComment>> watchForProduct(String productId);

  Future<void> addComment({
    required String productId,
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
