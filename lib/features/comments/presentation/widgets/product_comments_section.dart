import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';

import '../../domain/entities/product_comment.dart';
import '../controllers/comment_controller.dart';
import '../providers/comment_providers.dart';
import 'comment_composer.dart';
import 'product_comment_tile.dart';

/// The scrollable comment thread — replies-aware, like-aware — for
/// [productId]. Renders the list only; the top-level "add a comment"
/// composer lives one level up ([ProductCommentsModal]) so it can stay
/// pinned to the bottom of the sheet instead of scrolling away with the
/// thread. Kept distinct from `features/ratings` (post-purchase supplier
/// reviews).
class ProductCommentsSection extends ConsumerStatefulWidget {
  const ProductCommentsSection({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductCommentsSection> createState() =>
      _ProductCommentsSectionState();
}

class _ProductCommentsSectionState
    extends ConsumerState<ProductCommentsSection> {
  String? _replyingToId;

  Future<void> _submitReply(String parentId, String text) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addComment(productId: widget.productId, text: text, parentId: parentId);
    if (ok) setState(() => _replyingToId = null);
  }

  Future<void> _submitReplyImage(String parentId, XFile image) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addImageComment(
          productId: widget.productId,
          image: image,
          parentId: parentId,
        );
    if (ok) setState(() => _replyingToId = null);
  }

  Future<void> _submitReplyVoice(
    String parentId,
    String voicePath,
    int duration,
  ) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addVoiceComment(
          productId: widget.productId,
          voicePath: voicePath,
          durationSeconds: duration,
          parentId: parentId,
        );
    if (ok) setState(() => _replyingToId = null);
  }

  void _toggleReply(String commentId) {
    setState(() {
      _replyingToId = _replyingToId == commentId ? null : commentId;
    });
  }

  void _toggleLike(String commentId) {
    ref.read(commentControllerProvider.notifier).toggleLike(commentId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(currentUserProvider).valueOrNull?.id;
    final commentsAsync = ref.watch(productCommentsProvider(widget.productId));

    return commentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (comments) {
        final topLevel = comments.where((c) => !c.isReply).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (topLevel.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              'Aucun commentaire pour le moment. Soyez le premier à donner votre avis !',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children: [
            for (final comment in topLevel)
              ProductCommentTile(
                key: ValueKey(comment.id),
                comment: comment,
                replies: comments.where((c) => c.parentId == comment.id).toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
                isReplying: _replyingToId == comment.id,
                onToggleReply: () => _toggleReply(comment.id),
                onToggleLike: _toggleLike,
                currentUserId: currentUserId,
                replyComposer: CommentComposer(
                  key: ValueKey('reply-${comment.id}'),
                  hintText: 'Répondre...',
                  onSend: (text) => _submitReply(comment.id, text),
                  onSendImage: (path) => _submitReplyImage(comment.id, path),
                  onSendVoice: (path, duration) =>
                      _submitReplyVoice(comment.id, path, duration),
                ),
              ),
          ],
        );
      },
    );
  }
}
