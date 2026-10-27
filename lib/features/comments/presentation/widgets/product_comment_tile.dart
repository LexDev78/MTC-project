import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/core/widgets/role_badge.dart';
import 'package:mtc_app/core/widgets/voice_note_player.dart';

import '../../domain/entities/product_comment.dart';

/// One top-level comment plus its replies. Only top-level comments can be
/// replied to (see [ProductComment] doc) — replies render the same way but
/// indented, with no further "Répondre" action of their own.
class ProductCommentTile extends StatelessWidget {
  const ProductCommentTile({
    super.key,
    required this.comment,
    required this.replies,
    required this.isReplying,
    required this.onToggleReply,
    required this.onToggleLike,
    required this.currentUserId,
    required this.replyComposer,
  });

  final ProductComment comment;
  final List<ProductComment> replies;
  final bool isReplying;
  final VoidCallback onToggleReply;
  final void Function(String commentId) onToggleLike;
  final String? currentUserId;

  /// Built by the parent so it can own the [TextEditingController] and
  /// submit logic while staying scoped to this one comment's reply slot.
  /// Null unless [isReplying] is true.
  final Widget? replyComposer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBubble(
            comment: comment,
            isLiked: comment.isLikedBy(currentUserId),
            onToggleLike: () => onToggleLike(comment.id),
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, top: 2),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onToggleReply,
              child: Text(isReplying ? 'Annuler' : 'Répondre'),
            ),
          ),
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: 4),
              child: _CommentBubble(
                comment: reply,
                isLiked: reply.isLikedBy(currentUserId),
                onToggleLike: () => onToggleLike(reply.id),
              ),
            ),
          if (isReplying && replyComposer != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: 4),
              child: replyComposer,
            ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isLiked,
    required this.onToggleLike,
  });

  final ProductComment comment;
  final bool isLiked;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  comment.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (comment.isSupplier) ...[
                const SizedBox(width: AppSpacing.xs),
                RoleBadge(label: 'Fournisseur', color: scheme.primary),
              ],
              const Spacer(),
              Text(
                DateFormatter.relative(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (comment.attachmentType == CommentAttachmentType.image &&
              comment.attachmentPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _ImageAttachment(path: comment.attachmentPath!),
            ),
          if (comment.attachmentType == CommentAttachmentType.voice &&
              comment.attachmentPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: VoiceNotePlayer(
                path: comment.attachmentPath!,
                durationSeconds: comment.voiceDurationSeconds,
                bucket: 'comment-attachments',
              ),
            ),
          if (comment.text.isNotEmpty)
            Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          _LikeButton(
            liked: isLiked,
            count: comment.likeCount,
            onTap: onToggleLike,
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = liked ? scheme.error : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: color,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A photo shared in a comment — tap to view full-screen. [path] is a
/// `comment-attachments` Storage object path (public bucket — the Q&A
/// thread is public read, so a plain resolved URL is enough, no signing).
class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.path});

  final String path;

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: ResolvedImage(path: path, bucket: 'comment-attachments'),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: () => _openFullscreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: SizedBox(
          width: 180,
          height: 180,
          child: ResolvedImage(
            path: path,
            bucket: 'comment-attachments',
            // Matches the fixed 180x180 SizedBox above at ~2x, comfortably
            // covering standard device pixel ratios without decoding the
            // original upload's full resolution for this thumbnail.
            cacheWidth: 360,
            cacheHeight: 360,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      ),
    );
  }
}

