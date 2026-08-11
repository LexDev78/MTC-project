import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_comment.freezed.dart';

/// An open, purchase-independent comment on a product — distinct from
/// [Review] (ratings/features/ratings), which is gated to clients who
/// received a delivered order. Flat one-level threading: a top-level
/// comment (`parentId == null`) can have replies (`parentId` pointing back
/// to it), but a reply can't itself be replied to — keeps the Q&A simple.
@freezed
class ProductComment with _$ProductComment {
  const factory ProductComment({
    required String id,
    required String productId,
    required String authorId,
    required String authorName,
    required DateTime createdAt,
    required String text,

    /// True when the author is a supplier account (tiers or MTC principal)
    /// rather than a client — drives the "Fournisseur" badge in the UI.
    @Default(false) bool isSupplier,

    /// Null for a top-level comment; the top-level comment's id for a reply.
    String? parentId,
  }) = _ProductComment;
}

extension ProductCommentX on ProductComment {
  bool get isReply => parentId != null;
}
