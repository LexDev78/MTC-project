import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/role_badge.dart';

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
    required this.replyComposer,
  });

  final ProductComment comment;
  final List<ProductComment> replies;
  final bool isReplying;
  final VoidCallback onToggleReply;

  /// Built by the parent so it can own the [TextEditingController] and
  /// submit logic while staying scoped to this one comment's reply slot.
  final Widget replyComposer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBubble(comment: comment),
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
              child: _CommentBubble(comment: reply),
            ),
          if (isReplying)
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
  const _CommentBubble({required this.comment});

  final ProductComment comment;

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
          Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
