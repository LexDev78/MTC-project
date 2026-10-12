import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../controllers/comment_controller.dart';
import '../providers/comment_providers.dart';
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

  @override
  void initState() {
    super.initState();
    // `productCommentsProvider` is `autoDispose`, but a dismissed modal
    // route can still be kept alive briefly (exit animation) the same way
    // a popped page can — see `SupplierCommentInboxScreen`'s doc comment —
    // so force a fresh fetch every time this sheet actually opens rather
    // than trusting disposal timing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(productCommentsProvider(widget.productId));
    });
  }

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
            _ModalHeader(
              productId: widget.productId,
              onClose: () => Navigator.of(context).pop(),
            ),
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

/// Identifies which product this thread is about — critical from the
/// supplier's cross-product inbox (`SupplierCommentInboxScreen`), where one
/// modal serves whichever thread was tapped and there'd otherwise be
/// nothing here to say which listing "avp"/a one-line question is even
/// about. Doubles as a shortcut to that product: a client goes to its
/// public listing page, a supplier (who can't reach `/client/...`, see
/// `route_guards.dart`) to their own management form for it instead —
/// same split `_ProductAttachment` uses for a product referenced in chat.
class _ModalHeader extends ConsumerWidget {
  const _ModalHeader({required this.productId, required this.onClose});

  final String productId;
  final VoidCallback onClose;

  Future<void> _openProduct(BuildContext context, WidgetRef ref) async {
    final isClient = ref.read(currentUserProvider).valueOrNull is ClientUser;
    if (isClient) {
      unawaited(context.push(AppRoutes.productDetail(productId)));
      return;
    }
    final router = GoRouter.of(context);
    final prefix = ref.read(supplierRoutePrefixProvider);
    try {
      final product = await ref.read(productDetailProvider(productId).future);
      unawaited(router.push('$prefix/products/form', extra: product));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ce produit n'est plus disponible.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productDetailProvider(productId));
    final scheme = Theme.of(context).colorScheme;

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
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () => _openProduct(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    if (productAsync.valueOrNull case final product?) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: ProductImage(
                            imageUrl: product.imageUrls.isEmpty
                                ? null
                                : product.imageUrls.first,
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Commentaires',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (productAsync.valueOrNull case final product?)
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
