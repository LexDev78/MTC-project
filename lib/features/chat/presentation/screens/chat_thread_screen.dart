import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/currency_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/features/auth/domain/entities/app_user.dart';
import 'package:mtc_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mtc_app/features/catalog/domain/entities/product.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_status.dart';
import 'package:mtc_app/features/catalog/domain/entities/product_variant.dart';
import 'package:mtc_app/features/catalog/presentation/providers/supplier_product_providers.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductCategoryIcon, ProductImage;
import 'package:mtc_app/features/suppliers/presentation/providers/operating_supplier_providers.dart';

import '../controllers/chat_controller.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_composer.dart';
import '../widgets/message_bubble.dart';

/// A product (optionally a specific variant of it) staged to attach to the
/// next message sent — carried as a single `extra` payload wherever a route
/// pushes to a chat thread with something to attach (GoRouter's `extra`
/// only ever holds one object).
class ChatProductAttachment {
  const ChatProductAttachment({required this.product, this.variant});

  final Product product;
  final ProductVariant? variant;
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.initialAttachment,
  });

  final String conversationId;

  /// Set when the client opened this thread from a product page (or the
  /// supplier re-contacted a client about an ordered item) — pre-fills a
  /// pending attachment so the next message carries the
  /// product's/variant's name/price/photo automatically, rather than the
  /// other side having to guess which listing (and which variant of it)
  /// the message is about.
  final ChatProductAttachment? initialAttachment;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _scrollController = ScrollController();
  late ChatProductAttachment? _pendingAttachment = widget.initialAttachment;

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

  String? _attachmentImage(ChatProductAttachment? attachment) {
    if (attachment == null) return null;
    return attachment.variant?.imageUrls.firstOrNull ??
        (attachment.product.imageUrls.isEmpty
            ? null
            : attachment.product.imageUrls.first);
  }

  int? _attachmentPrice(ChatProductAttachment? attachment) {
    if (attachment == null) return null;
    return attachment.variant?.priceFcfa ?? attachment.product.priceFcfa;
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

  /// Lets the supplier tag one of their own products onto the message
  /// they're about to send, from inside an already-open thread — the only
  /// existing way to get a product attached (`ChatProductAttachment`) was
  /// starting a *new* conversation from that product's page. Stages it into
  /// the exact same [_pendingAttachment] flow that path already feeds, so
  /// sending/removing it works identically either way.
  Future<void> _pickProductToAttach() async {
    final supplierId = ref.read(operatingSupplierIdProvider);
    if (supplierId == null) return;
    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductAttachmentPicker(supplierId: supplierId),
    );
    if (selected == null || !mounted) return;
    final defaultVariant = selected.hasVariants
        ? (selected.variants.firstWhereOrNull((v) => v.isDefault) ??
              selected.variants.firstOrNull)
        : null;
    setState(() {
      _pendingAttachment = ChatProductAttachment(
        product: selected,
        variant: defaultVariant,
      );
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
      if (!next.hasValue) return;
      _scrollToBottom();
      // A message that streams in while this thread is already open must
      // never sit as "unread" — re-mark-read on every emission, not just
      // once in initState, so a mid-session arrival from the other side
      // clears its own badge/notification immediately instead of waiting
      // for the next time this screen happens to mount.
      final previousCount = previous?.valueOrNull?.length ?? 0;
      if (next.value!.length > previousCount) {
        ref.read(chatControllerProvider.notifier).markRead(widget.conversationId);
      }
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
                      isClient: isClient,
                    );
                  },
                );
              },
            ),
          ),
          if (_pendingAttachment != null)
            _PendingProductAttachment(
              attachment: _pendingAttachment!,
              onRemove: () => setState(() => _pendingAttachment = null),
            ),
          ChatComposer(
            // No key tied to `_pendingAttachment` (there used to be one,
            // keyed on the product id) — that would tear down and rebuild
            // `_ChatComposerState` on every attach/remove, silently
            // discarding whatever the supplier had already typed if they
            // tag a product mid-message rather than before starting one.
            onAttachProduct: isClient ? null : _pickProductToAttach,
            hasPendingAttachment: _pendingAttachment != null,
            onSend: (text) {
              final attachment = _pendingAttachment;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendMessage(
                    conversationId: widget.conversationId,
                    text: text,
                    productId: attachment?.product.id,
                    productNameSnapshot: attachment?.product.name,
                    productImageSnapshot: _attachmentImage(attachment),
                    productPriceFcfaSnapshot: _attachmentPrice(attachment),
                    productVariantId: attachment?.variant?.id,
                    productVariantNameSnapshot: attachment?.variant?.name,
                  );
              if (attachment != null) setState(() => _pendingAttachment = null);
            },
            onSendImage: (image) {
              final attachment = _pendingAttachment;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendImage(
                    conversationId: widget.conversationId,
                    image: image,
                    productId: attachment?.product.id,
                    productNameSnapshot: attachment?.product.name,
                    productImageSnapshot: _attachmentImage(attachment),
                    productPriceFcfaSnapshot: _attachmentPrice(attachment),
                    productVariantId: attachment?.variant?.id,
                    productVariantNameSnapshot: attachment?.variant?.name,
                  );
              if (attachment != null) setState(() => _pendingAttachment = null);
            },
            onSendVoice: (voicePath, durationSeconds) {
              final attachment = _pendingAttachment;
              ref
                  .read(chatControllerProvider.notifier)
                  .sendVoiceNote(
                    conversationId: widget.conversationId,
                    voicePath: voicePath,
                    durationSeconds: durationSeconds,
                    productId: attachment?.product.id,
                    productNameSnapshot: attachment?.product.name,
                    productImageSnapshot: _attachmentImage(attachment),
                    productPriceFcfaSnapshot: _attachmentPrice(attachment),
                    productVariantId: attachment?.variant?.id,
                    productVariantNameSnapshot: attachment?.variant?.name,
                  );
              if (attachment != null) setState(() => _pendingAttachment = null);
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
    required this.attachment,
    required this.onRemove,
  });

  final ChatProductAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final product = attachment.product;
    final variant = attachment.variant;
    final imageUrl =
        variant?.imageUrls.firstOrNull ??
        (product.imageUrls.isEmpty ? null : product.imageUrls.first);

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
              child: ProductImage(imageUrl: imageUrl, icon: Icons.inventory_2_outlined),
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
                  variant == null ? product.name : '${product.name} — ${variant.name}',
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

/// Sheet listing the operating supplier's own active products to tag onto
/// their next message — pops the picked one back to
/// `_ChatThreadScreenState._pickProductToAttach`, or `null` on dismiss.
/// Scoped to `active` only: a draft/paused listing isn't reachable by the
/// client the message would go to, so attaching one would just be a dead
/// link on their end.
class _ProductAttachmentPicker extends ConsumerWidget {
  const _ProductAttachmentPicker({required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(myProductsProvider(supplierId));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text(
              'Taguer un produit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Expanded(
            child: AsyncValueWidget(
              value: productsAsync,
              data: (products) {
                final active = products
                    .where((p) => p.status == ProductStatus.active)
                    .toList();
                if (active.isEmpty) {
                  return const MtcEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit actif',
                    subtitle: 'Activez un produit pour pouvoir le taguer ici.',
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: active.length,
                  itemBuilder: (context, index) {
                    final product = active[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: ProductImage(
                            imageUrl: product.imageUrls.firstOrNull,
                            icon: product.category.icon,
                          ),
                        ),
                      ),
                      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        CurrencyFormatter.formatFcfa(product.priceFcfa),
                      ),
                      onTap: () => Navigator.of(context).pop(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
