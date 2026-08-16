import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/core/widgets/voice_note_player.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/product_card.dart'
    show ProductImage;

import '../../domain/entities/chat.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBubble = isMine ? scheme.onPrimary : scheme.onSurface;
    final hasCardContent =
        message.productNameSnapshot != null ||
        message.attachmentType == ChatAttachmentType.image;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.fromLTRB(
          hasCardContent ? AppSpacing.xs : AppSpacing.md,
          hasCardContent ? AppSpacing.xs : AppSpacing.sm,
          hasCardContent ? AppSpacing.xs : AppSpacing.md,
          AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppSpacing.radiusMd),
            topRight: const Radius.circular(AppSpacing.radiusMd),
            bottomLeft: Radius.circular(isMine ? AppSpacing.radiusMd : 2),
            bottomRight: Radius.circular(isMine ? 2 : AppSpacing.radiusMd),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.productNameSnapshot != null)
              _ProductAttachment(message: message, onBubble: onBubble),
            if (message.attachmentType == ChatAttachmentType.image &&
                message.attachmentPath != null)
              _ImageAttachment(path: message.attachmentPath!),
            if (message.attachmentType == ChatAttachmentType.voice &&
                message.attachmentPath != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                child: VoiceNotePlayer(
                  path: message.attachmentPath!,
                  durationSeconds: message.voiceDurationSeconds,
                  bucket: 'chat-attachments',
                  signed: true,
                  color: onBubble,
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: hasCardContent ? AppSpacing.sm : 0,
                  right: hasCardContent ? AppSpacing.sm : 0,
                  top: hasCardContent ? AppSpacing.xs : 0,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: onBubble),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                right: hasCardContent ? AppSpacing.sm : 0,
                top: 2,
              ),
              child: Text(
                DateFormatter.formatTime(message.sentAt),
                style: TextStyle(
                  fontSize: 10,
                  color: onBubble.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The product "card" a message carries when the client started (or
/// continued) the conversation from a product page — tapping it jumps back
/// to that product so the supplier-side context is one tap away too.
class _ProductAttachment extends StatelessWidget {
  const _ProductAttachment({required this.message, required this.onBubble});

  final ChatMessage message;
  final Color onBubble;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      onTap: message.productId == null
          ? null
          : () => context.push(AppRoutes.productDetail(message.productId!)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: onBubble.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm - 2),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ProductImage(
                  imageUrl: message.productImageSnapshot,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.productNameSnapshot!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onBubble,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (message.productPriceFcfaSnapshot != null)
                    CurrencyText(
                      message.productPriceFcfaSnapshot!,
                      style: TextStyle(
                        color: onBubble.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gallery photo attached to a message — tap to view full-screen. [path]
/// is a `chat-attachments` Storage object path (private bucket, signed URL
/// resolved at display time — see `ResolvedImage`), not a local file.
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
                child: ResolvedImage(
                  path: path,
                  bucket: 'chat-attachments',
                  signed: true,
                ),
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
          width: 200,
          height: 200,
          child: ResolvedImage(
            path: path,
            bucket: 'chat-attachments',
            signed: true,
            // Matches the fixed 200x200 SizedBox above at ~2x — avoids
            // decoding the original upload's full resolution for this
            // bubble thumbnail, on every message in a scrolling thread.
            cacheWidth: 400,
            cacheHeight: 400,
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

