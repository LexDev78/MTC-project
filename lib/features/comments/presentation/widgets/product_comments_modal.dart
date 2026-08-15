import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

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

class ProductCommentsModal extends ConsumerStatefulWidget {
  const ProductCommentsModal({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductCommentsModal> createState() => _ProductCommentsModalState();
}

class _ProductCommentsModalState extends ConsumerState<ProductCommentsModal> {
  // Null when no reply row is open. While a reply is open the pinned
  // composer below is hidden, so only one text input is ever on screen.
  String? _replyingToId;

  Future<void> _submit(String text) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addComment(productId: widget.productId, text: text);
  }

  Future<void> _submitImage(XFile image) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addImageComment(productId: widget.productId, image: image);
  }

  Future<void> _submitVoice(String voicePath, int duration) async {
    await ref
        .read(commentControllerProvider.notifier)
        .addVoiceComment(
          productId: widget.productId,
          voicePath: voicePath,
          durationSeconds: duration,
        );
  }

  @override
  Widget build(BuildContext context) {
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
                child: ProductCommentsSection(
                  productId: widget.productId,
                  replyingToId: _replyingToId,
                  onReplyingChanged: (id) => setState(() => _replyingToId = id),
                ),
              ),
            ),
            if (_replyingToId == null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: CommentComposer(
                  hintText: 'Ajouter un commentaire...',
                  onSend: _submit,
                  onSendImage: _submitImage,
                  onSendVoice: _submitVoice,
                ),
              ),
            ],
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
