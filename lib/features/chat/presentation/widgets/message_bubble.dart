import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mtc_app/app/router/app_routes.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/core_widgets.dart';
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
                child: _VoiceMessage(
                  path: message.attachmentPath!,
                  durationSeconds: message.voiceDurationSeconds,
                  onBubble: onBubble,
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

/// A gallery photo attached to a message — tap to view full-screen. Local
/// file only (no upload backend), so it disappears if the app's temp/cache
/// storage is cleared, same lifetime as every other mock record here.
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
              child: Center(child: Image.file(File(path))),
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
        child: Image.file(
          File(path),
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 200,
            height: 200,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

/// A voice-note bubble — play/pause plus an elapsed/total duration label.
/// Local file only, same caveat as [_ImageAttachment].
class _VoiceMessage extends StatefulWidget {
  const _VoiceMessage({
    required this.path,
    required this.durationSeconds,
    required this.onBubble,
  });

  final String path;
  final int? durationSeconds;
  final Color onBubble;

  @override
  State<_VoiceMessage> createState() => _VoiceMessageState();
}

class _VoiceMessageState extends State<_VoiceMessage> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(DeviceFileSource(widget.path));
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.durationSeconds != null
        ? Duration(seconds: widget.durationSeconds!)
        : _position;
    final label = _position > Duration.zero ? _position : total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            _isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
            color: widget.onBubble,
            size: 32,
          ),
          onPressed: _toggle,
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          Icons.graphic_eq_rounded,
          color: widget.onBubble.withValues(alpha: 0.7),
          size: 18,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _format(label),
          style: TextStyle(
            color: widget.onBubble,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
