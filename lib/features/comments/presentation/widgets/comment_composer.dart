import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

/// Text/photo/voice composer for a comment or a reply — same input
/// mechanics as `ChatComposer` (features/chat), duplicated rather than
/// shared so each feature keeps its own presentation layer self-contained.
class CommentComposer extends StatefulWidget {
  const CommentComposer({
    super.key,
    required this.hintText,
    required this.onSend,
    required this.onSendImage,
    required this.onSendVoice,
  });

  final String hintText;
  final void Function(String text) onSend;
  final void Function(XFile image) onSendImage;
  final void Function(String voicePath, int durationSeconds) onSendVoice;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  Timer? _recordTimer;
  bool _isRecording = false;
  int _recordSeconds = 0;

  @override
  void dispose() {
    _controller.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  void _showAccessDeniedSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) widget.onSendImage(file);
    } catch (_) {
      _showAccessDeniedSnackBar(
        "Impossible d'accéder à la galerie. Vérifiez l'autorisation dans les réglages du téléphone.",
      );
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showAccessDeniedSnackBar(
        'Autorisation microphone refusée. Activez-la dans les réglages pour envoyer un commentaire vocal.',
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/comment_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordSeconds;
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });
    if (path == null) return;
    if (send && duration > 0) {
      widget.onSendVoice(path, duration);
    } else {
      unawaited(File(path).delete().catchError((_) => File(path)));
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _isRecording ? _recordingRow(scheme) : _textRow(scheme);
  }

  Widget _textRow(ColorScheme scheme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.image_outlined),
          tooltip: 'Partager une photo',
          onPressed: _pickImage,
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: widget.hintText),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          onPressed: _controller.text.trim().isEmpty ? _startRecording : _submit,
          icon: Icon(
            _controller.text.trim().isEmpty
                ? Icons.mic_none_rounded
                : Icons.send_rounded,
          ),
        ),
      ],
    );
  }

  Widget _recordingRow(ColorScheme scheme) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          tooltip: 'Annuler',
          onPressed: () => _stopRecording(send: false),
        ),
        Expanded(
          child: Row(
            children: [
              _PulsingDot(color: scheme.error),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Enregistrement · ${_formatDuration(_recordSeconds)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        IconButton.filled(
          icon: const Icon(Icons.send_rounded),
          tooltip: 'Envoyer',
          onPressed: () => _stopRecording(send: true),
        ),
      ],
    );
  }
}

/// Small breathing red dot indicating an active recording — same idiom as
/// `ChatComposer`'s.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.3).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
