import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/product_comment.dart';
import '../controllers/comment_controller.dart';
import '../providers/comment_providers.dart';
import 'product_comment_tile.dart';

/// Open, purchase-independent comment thread for a product — any signed-in
/// client or supplier can post a top-level comment or reply to one. Kept
/// distinct from `features/ratings` (post-purchase supplier reviews).
class ProductCommentsSection extends ConsumerStatefulWidget {
  const ProductCommentsSection({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductCommentsSection> createState() =>
      _ProductCommentsSectionState();
}

class _ProductCommentsSectionState
    extends ConsumerState<ProductCommentsSection> {
  final _composerController = TextEditingController();
  final _replyController = TextEditingController();
  String? _replyingToId;

  @override
  void dispose() {
    _composerController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitTopLevel() async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addComment(productId: widget.productId, text: _composerController.text);
    if (ok) _composerController.clear();
  }

  Future<void> _submitReply(String parentId) async {
    final ok = await ref
        .read(commentControllerProvider.notifier)
        .addComment(
          productId: widget.productId,
          text: _replyController.text,
          parentId: parentId,
        );
    if (ok) {
      _replyController.clear();
      setState(() => _replyingToId = null);
    }
  }

  void _toggleReply(String commentId) {
    setState(() {
      _replyingToId = _replyingToId == commentId ? null : commentId;
      _replyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final commentsAsync = ref.watch(productCommentsProvider(widget.productId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commentaires', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        commentsAsync.when(
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
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Aucun commentaire pour le moment. Soyez le premier à donner votre avis !',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (final comment in topLevel)
                  ProductCommentTile(
                    comment: comment,
                    replies: comments.where((c) => c.parentId == comment.id).toList()
                      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
                    isReplying: _replyingToId == comment.id,
                    onToggleReply: () => _toggleReply(comment.id),
                    replyComposer: _Composer(
                      controller: _replyController,
                      hintText: 'Répondre...',
                      onSubmit: () => _submitReply(comment.id),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        _Composer(
          controller: _composerController,
          hintText: 'Ajouter un commentaire...',
          onSubmit: _submitTopLevel,
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(hintText: hintText),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          onPressed: onSubmit,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}
