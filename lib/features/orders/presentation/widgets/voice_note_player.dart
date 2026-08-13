import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Play/pause + elapsed/total duration for a locally-recorded voice note —
/// same idiom as the chat and comments features' voice bubbles, factored
/// out here since the orders feature uses it in two places (the checkout
/// form's preview row and the order-detail summary).
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.path,
    required this.durationSeconds,
    this.compact = false,
  });

  final String path;
  final int? durationSeconds;

  /// Smaller icon/no extra padding, for embedding inside a tight row.
  final bool compact;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
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
    final iconSize = widget.compact ? 26.0 : 32.0;

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
            size: iconSize,
          ),
          onPressed: _toggle,
        ),
        const SizedBox(width: AppSpacing.xs),
        Icon(Icons.graphic_eq_rounded, color: scheme.onSurfaceVariant, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _format(label),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
