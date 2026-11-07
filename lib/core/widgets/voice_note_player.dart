import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';

/// Play/pause + elapsed/total duration for a voice note. Shared by the
/// checkout form's own preview, order detail, chat bubbles, and comment
/// attachments — previously four near-identical copies of the same player,
/// consolidated here once a real resolution step (Storage path → playable
/// URL) was needed rather than just duplicated once more.
///
/// [path] is a **local device file** when [bucket] is left null (e.g. a
/// just-recorded note in the checkout form's own preview row, before it's
/// been uploaded anywhere yet) — otherwise it's a Storage object path,
/// resolved to a public or (when [signed]) signed URL only at the moment
/// playback starts, never eagerly.
class VoiceNotePlayer extends ConsumerStatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.path,
    required this.durationSeconds,
    this.compact = false,
    this.bucket,
    this.signed = false,
    this.color,
  });

  final String path;
  final int? durationSeconds;

  /// Smaller icon/no extra padding, for embedding inside a tight row.
  final bool compact;

  final String? bucket;
  final bool signed;

  /// Overrides the icon/text color — needed inside a chat bubble, whose
  /// "mine" variant sits on a colored background rather than the surface.
  final Color? color;

  @override
  ConsumerState<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends ConsumerState<VoiceNotePlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isResolving = false;
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
      return;
    }
    final bucket = widget.bucket;
    if (bucket == null) {
      await _player.play(DeviceFileSource(widget.path));
      return;
    }
    setState(() => _isResolving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final url = widget.signed
          ? await client.storage.from(bucket).createSignedUrl(widget.path, 3600)
          : client.storage.from(bucket).getPublicUrl(widget.path);
      await _player.play(UrlSource(url));
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final subtleColor = widget.color?.withValues(alpha: 0.7) ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final total = widget.durationSeconds != null
        ? Duration(seconds: widget.durationSeconds!)
        : _position;
    final label = _position > Duration.zero ? _position : total;
    final iconSize = widget.compact ? 26.0 : 32.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: _isResolving
              ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: color,
                    size: iconSize,
                  ),
                  onPressed: _toggle,
                ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(Icons.graphic_eq_rounded, color: subtleColor, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _format(label),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: widget.color,
              ),
        ),
      ],
    );
  }
}
