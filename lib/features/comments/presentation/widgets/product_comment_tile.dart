import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/utils/date_formatter.dart';
import 'package:mtc_app/core/widgets/role_badge.dart';

import '../../domain/entities/product_comment.dart';

/// One top-level comment plus its replies. Only top-level comments can be
/// replied to (see [ProductComment] doc) — replies render the same way but
/// indented, with no further "Répondre" action of their own.
class ProductCommentTile extends StatelessWidget {
  const ProductCommentTile({
    super.key,
    required this.comment,
    required this.replies,
    required this.isReplying,
    required this.onToggleReply,
    required this.onToggleLike,
    required this.currentUserId,
    required this.replyComposer,
  });

  final ProductComment comment;
  final List<ProductComment> replies;
  final bool isReplying;
  final VoidCallback onToggleReply;
  final void Function(String commentId) onToggleLike;
  final String? currentUserId;

  /// Built by the parent so it can own the [TextEditingController] and
  /// submit logic while staying scoped to this one comment's reply slot.
  final Widget replyComposer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentBubble(
            comment: comment,
            isLiked: comment.isLikedBy(currentUserId),
            onToggleLike: () => onToggleLike(comment.id),
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, top: 2),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onToggleReply,
              child: Text(isReplying ? 'Annuler' : 'Répondre'),
            ),
          ),
          for (final reply in replies)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: 4),
              child: _CommentBubble(
                comment: reply,
                isLiked: reply.isLikedBy(currentUserId),
                onToggleLike: () => onToggleLike(reply.id),
              ),
            ),
          if (isReplying)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg, top: 4),
              child: replyComposer,
            ),
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble({
    required this.comment,
    required this.isLiked,
    required this.onToggleLike,
  });

  final ProductComment comment;
  final bool isLiked;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  comment.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (comment.isSupplier) ...[
                const SizedBox(width: AppSpacing.xs),
                RoleBadge(label: 'Fournisseur', color: scheme.primary),
              ],
              const Spacer(),
              Text(
                DateFormatter.relative(comment.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (comment.attachmentType == CommentAttachmentType.image &&
              comment.attachmentPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _ImageAttachment(path: comment.attachmentPath!),
            ),
          if (comment.attachmentType == CommentAttachmentType.voice &&
              comment.attachmentPath != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _VoiceAttachment(
                path: comment.attachmentPath!,
                durationSeconds: comment.voiceDurationSeconds,
              ),
            ),
          if (comment.text.isNotEmpty)
            Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          _LikeButton(
            liked: isLiked,
            count: comment.likeCount,
            onTap: onToggleLike,
          ),
        ],
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.count,
    required this.onTap,
  });

  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = liked ? scheme.error : scheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: color,
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A photo shared in a comment — tap to view full-screen. Local file only
/// (no upload backend), same lifetime caveat as the chat feature's version.
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
          width: 180,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 180,
            height: 180,
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }
}

/// A voice-note comment — play/pause plus an elapsed/total duration label.
/// Local file only, same caveat as [_ImageAttachment].
class _VoiceAttachment extends StatefulWidget {
  const _VoiceAttachment({required this.path, required this.durationSeconds});

  final String path;
  final int? durationSeconds;

  @override
  State<_VoiceAttachment> createState() => _VoiceAttachmentState();
}

class _VoiceAttachmentState extends State<_VoiceAttachment> {
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
    final scheme = Theme.of(context).colorScheme;
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
            color: scheme.primary,
            size: 32,
          ),
          onPressed: _toggle,
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(
          Icons.graphic_eq_rounded,
          color: scheme.onSurfaceVariant,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _format(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
