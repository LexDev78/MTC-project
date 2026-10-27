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
///
/// [replyingToId]/[onReplyingChanged] are owned by [ProductCommentsModal] so
/// it can hide its pinned composer while a reply row is open — otherwise two
/// text inputs (the pinned one and the inline reply one) would be visible at
/// once.
class ProductCommentsSection extends ConsumerWidget {
  const ProductCommentsSection({
    super.key,
    required this.productId,
    required this.replyingToId,
    required this.onReplyingChanged,
  });

  final String productId;
  final String? replyingToId;
  final ValueChanged<String?> onReplyingChanged;

  Future<void> _submitReply(WidgetRef ref, String parentId, String text) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addComment(productId: productId, text: text, parentId: parentId);
    if (ok) onReplyingChanged(null);
  }

  Future<void> _submitReplyImage(WidgetRef ref, String parentId, XFile image) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addImageComment(productId: productId, image: image, parentId: parentId);
    if (ok) onReplyingChanged(null);
  }

  Future<void> _submitReplyVoice(
    WidgetRef ref,
    String parentId,
    String voicePath,
    int duration,
  ) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addVoiceComment(
          productId: productId,
          voicePath: voicePath,
          durationSeconds: duration,
          parentId: parentId,
        );
    if (ok) onReplyingChanged(null);
  }

  void _toggleReply(String commentId) {
    onReplyingChanged(replyingToId == commentId ? null : commentId);
  }

  void _toggleLike(WidgetRef ref, String commentId) {
    ref.read(commentControllerProvider.notifier).toggleLike(commentId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // `.select()` — only the id is used below, so a reply/like elsewhere in
    // the app shouldn't re-run this whole thread's build.
    final currentUserId = ref.watch(
      currentUserProvider.select((u) => u.valueOrNull?.id),
    );
    final commentsAsync = ref.watch(productCommentsProvider(productId));

    return commentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (comments) {
        final topLevel = comments.where((c) => !c.isReply).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // One pass to group replies by parent instead of re-scanning the
        // full comment list per top-level comment below (was O(n²) on
        // threads with many replies).
        final repliesByParent = <String, List<ProductComment>>{};
        for (final comment in comments) {
          final parentId = comment.parentId;
          if (parentId != null) {
            (repliesByParent[parentId] ??= []).add(comment);
          }
        }
        for (final replies in repliesByParent.values) {
          replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }

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
                replies: repliesByParent[comment.id] ?? const [],
                isReplying: replyingToId == comment.id,
                onToggleReply: () => _toggleReply(comment.id),
                onToggleLike: (id) => _toggleLike(ref, id),
                currentUserId: currentUserId,
                replyComposer: replyingToId != comment.id
                    ? null
                    : CommentComposer(
                        key: ValueKey('reply-${comment.id}'),
                        hintText: 'Répondre...',
                        autofocus: true,
                        onSend: (text) => _submitReply(ref, comment.id, text),
                        onSendImage: (path) =>
                            _submitReplyImage(ref, comment.id, path),
                        onSendVoice: (path, duration) =>
                            _submitReplyVoice(ref, comment.id, path, duration),
                      ),
              ),
          ],
        );
      },
    );
  }
}
