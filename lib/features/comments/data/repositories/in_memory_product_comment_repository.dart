import 'package:mtc_app/core/utils/id_generator.dart';

import '../../domain/entities/product_comment.dart';
import '../../domain/repositories/product_comment_repository.dart';
import '../datasources/in_memory_product_comment_datasource.dart';

class InMemoryProductCommentRepository implements ProductCommentRepository {
  InMemoryProductCommentRepository(this._datasource);

  final InMemoryProductCommentDatasource _datasource;

  @override
  Stream<List<ProductComment>> watchForProduct(String productId) {
    return _datasource.watchForProduct(productId);
  }

  @override
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
  }) async {
    _datasource.addComment(
      ProductComment(
        id: IdGenerator.next(),
        productId: productId,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        text: text,
        isSupplier: isSupplier,
        parentId: parentId,
        attachmentType: attachmentType,
        attachmentPath: attachmentPath,
        voiceDurationSeconds: voiceDurationSeconds,
      ),
    );
  }

  @override
  Future<void> toggleLike({
    required String commentId,
    required String userId,
  }) async {
    _datasource.toggleLike(commentId, userId);
  }
}
