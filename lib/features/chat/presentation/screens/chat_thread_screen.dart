import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;

import '../controllers/chat_controller.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.initialProduct,
  });

  final String conversationId;

  /// Set when the client opened this thread from a product page — pre-fills
  /// a pending attachment so their next message carries the product's
  /// name/price/photo automatically, rather than the supplier having to
  /// guess which listing the question is about.
  final Product? initialProduct;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _scrollController = ScrollController();
  late Product? _pendingProduct = widget.initialProduct;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(chatControllerProvider.notifier)
          .markRead(widget.conversationId),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final conversation = ref.watch(conversationProvider(widget.conversationId));
    // `.select()` a `(id, isClient)` record rather than the whole `AppUser`
    // — this screen only ever needs those two facts, and a bare watch would
    // rebuild the entire message list on any re-emission of the user stream.
    final (currentUserId, isClient) = ref.watch(
      currentUserProvider.select(
        (u) => (u.valueOrNull?.id, u.valueOrNull is ClientUser),
      ),
    );

    ref.listen(messagesProvider(widget.conversationId), (previous, next) {
      if (next.hasValue) _scrollToBottom();
    });

    final title = isClient
        ? conversation?.supplierName
        : conversation?.clientDisplayNameSnapshot;

    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Conversation')),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueWidget(
              value: messagesAsync,
              data: (messages) {
                if (messages.isEmpty) {
                  return const MtcEmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Démarrez la conversation',
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return MessageBubble(
                      message: message,
                      isMine: message.senderId == currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          if (_pendingProduct != null)
            _PendingProductAttachment(
              product: _pendingProduct!,
              onRemove: () => setState(() => _pendingProduct = null),
            ),
          ChatComposer(
            key: ValueKey(_pendingProduct?.id),
            onSend: (text) {
              final product = _pendingProduct;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendMessage(
                    conversationId: widget.conversationId,
                    text: text,
                    productId: product?.id,
                    productNameSnapshot: product?.name,
                    productImageSnapshot: product?.imageUrls.isNotEmpty == true
                        ? product!.imageUrls.first
                        : null,
                    productPriceFcfaSnapshot: product?.priceFcfa,
                  );
              if (product != null) setState(() => _pendingProduct = null);
            },
            onSendImage: (image) {
              final product = _pendingProduct;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendImage(
                    conversationId: widget.conversationId,
                    image: image,
                    productId: product?.id,
                    productNameSnapshot: product?.name,
                    productImageSnapshot: product?.imageUrls.isNotEmpty == true
                        ? product!.imageUrls.first
                        : null,
                    productPriceFcfaSnapshot: product?.priceFcfa,
                  );
              if (product != null) setState(() => _pendingProduct = null);
            },
            onSendVoice: (voicePath, durationSeconds) {
              final product = _pendingProduct;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendVoiceNote(
                    conversationId: widget.conversationId,
                    voicePath: voicePath,
                    durationSeconds: durationSeconds,
                    productId: product?.id,
                    productNameSnapshot: product?.name,
                    productImageSnapshot: product?.imageUrls.isNotEmpty == true
                        ? product!.imageUrls.first
                        : null,
                    productPriceFcfaSnapshot: product?.priceFcfa,
                  );
              if (product != null) setState(() => _pendingProduct = null);
            },
          ),
        ],
      ),
    );
  }
}

/// Shown above the composer while a product is queued to be attached to the
/// client's next message — lets them see (and remove) what's about to be
/// sent before it actually goes out.
class _PendingProductAttachment extends StatelessWidget {
  const _PendingProductAttachment({
    required this.product,
    required this.onRemove,
  });

  final Product product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: scheme.surfaceContainerHigh,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: 40,
              height: 40,
              child: ProductImage(
                imageUrl: product.imageUrls.isEmpty
                    ? null
                    : product.imageUrls.first,
                icon: Icons.inventory_2_outlined,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Question à propos de ce produit',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
            tooltip: 'Retirer',
          ),
        ],
      ),
    );
  }
}
