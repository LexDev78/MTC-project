import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../controllers/comment_controller.dart';
import 'comment_composer.dart';
import 'product_comments_section.dart';

/// Opens the comments modal for [productId] — a draggable sheet (starts at
/// 70% of the screen, can be pulled up to 95%) so the thread has real room
/// to breathe without leaving the product page.
Future<void> showProductCommentsModal(
  BuildContext context, {
  required String productId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    builder: (context) => Padding(
      // Keeps the pinned composer above the keyboard — `showModalBottomSheet`
      // doesn't resize for it on its own the way a `Scaffold` does.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ProductCommentsModal(productId: productId),
    ),
  );
}

class ProductCommentsModal extends ConsumerWidget {
  const ProductCommentsModal({super.key, required this.productId});

  final String productId;

  Future<void> _submit(WidgetRef ref, String text) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addComment(productId: productId, text: text);
  }

  Future<void> _submitImage(WidgetRef ref, String imagePath) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addImageComment(productId: productId, imagePath: imagePath);
  }

  Future<void> _submitVoice(WidgetRef ref, String voicePath, int duration) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addVoiceComment(
          productId: productId,
          voicePath: voicePath,
          durationSeconds: duration,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const _ModalHandle(),
            _ModalHeader(onClose: () => Navigator.of(context).pop()),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ProductCommentsSection(productId: productId),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: CommentComposer(
                hintText: 'Ajouter un commentaire...',
                onSend: (text) => _submit(ref, text),
                onSendImage: (path) => _submitImage(ref, path),
                onSendVoice: (path, duration) => _submitVoice(ref, path, duration),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModalHandle extends StatelessWidget {
  const _ModalHandle();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: scheme.outlineVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Commentaires', style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
