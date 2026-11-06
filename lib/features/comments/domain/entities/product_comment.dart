import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_comment.freezed.dart';
part 'product_comment.g.dart';

/// What a [ProductComment] carries beyond (or instead of) plain text —
/// mirrors `ChatAttachmentType` (features/chat), same local-file-only caveat.
enum CommentAttachmentType { none, image, voice }

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

    /// Resolved from `Product.supplierId` at creation time (denormalized,
    /// same reasoning as every other snapshot in this app) — lets the
    /// supplier's comment inbox filter across all of their products
    /// without a live join back to the catalog.
    required String supplierId,
    required String authorName,
    required DateTime createdAt,
    required String text,

    /// True when the author is a supplier account (tiers or MTC principal)
    /// rather than a client — drives the "Fournisseur" badge in the UI.
    @Default(false) bool isSupplier,

    /// Null for a top-level comment; the top-level comment's id for a reply.
    String? parentId,

    /// Local file path for an image or voice-note attachment — same
    /// no-upload-backend caveat as `ChatMessage.attachmentPath`.
    @Default(CommentAttachmentType.none) CommentAttachmentType attachmentType,
    String? attachmentPath,

    /// Set only for [CommentAttachmentType.voice], so the bubble can show a
    /// duration immediately without probing the audio file.
    int? voiceDurationSeconds,

    /// Le nombre de « j'aime », et si l'appelant en fait partie — calculés
    /// par la vue `product_comments_with_likes` (`0140`). Elle rendait la
    /// liste des identifiants de tous ceux qui avaient aimé, et l'auteur de
    /// chaque commentaire : plus maintenant.
    @Default(0) int likeCount,
    @Default(false) bool likedByMe,

    /// Écrit par l'appelant (ou par la boutique qu'il opère).
    @Default(false) bool isMine,
  }) = _ProductComment;

  factory ProductComment.fromJson(Map<String, dynamic> json) =>
      _$ProductCommentFromJson(json);
}

extension ProductCommentX on ProductComment {
  bool get isReply => parentId != null;
}
