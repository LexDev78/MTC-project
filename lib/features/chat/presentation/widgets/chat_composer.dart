import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:mtc_app/app/theme/app_shadows.dart';
import 'package:mtc_app/app/theme/app_spacing.dart';

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.onSendImage,
    required this.onSendVoice,
    this.initialText,
    this.onAttachProduct,
    this.hasPendingAttachment = false,
  });

  final void Function(String text) onSend;
  final void Function(XFile image) onSendImage;
  final void Function(String voicePath, int durationSeconds) onSendVoice;

  /// Pre-fills the field — used when the composer opens with a pending
  /// product attachment, so there's a ready-to-edit question instead of an
  /// empty box next to a silent attachment chip.
  final String? initialText;

  /// Shows a "tag a product" icon next to the photo one when set — the
  /// supplier side only (see `ChatThreadScreen`, which leaves this `null`
  /// for a client: they already get a product staged automatically by
  /// opening a thread from that product's page, see `ChatProductAttachment`).
  final VoidCallback? onAttachProduct;

  /// Whether a product is already staged to go out with the next message —
  /// lets an empty-text send go through (and puts the send icon up front
  /// instead of the mic) since "just the tagged product, no comment" is a
  /// normal thing to send, not something that should require typing a
  /// throwaway word first.
  final bool hasPendingAttachment;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final _controller = TextEditingController(text: widget.initialText);
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

  bool get _canSend =>
      _controller.text.trim().isNotEmpty || widget.hasPendingAttachment;

  void _submit() {
    if (!_canSend) return;
    widget.onSend(_controller.text.trim());
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
        'Autorisation microphone refusée. Activez-la dans les réglages pour envoyer un message vocal.',
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: scheme.surface, boxShadow: AppShadows.bar(brightness)),
      child: SafeArea(
        top: false,
        child: _isRecording ? _recordingRow(scheme) : _textRow(scheme),
      ),
    );
  }

  Widget _textRow(ColorScheme scheme) {
    return Row(
      children: [
        if (widget.onAttachProduct != null)
          IconButton(
            icon: const Icon(Icons.sell_outlined),
            tooltip: 'Taguer un produit',
            onPressed: widget.onAttachProduct,
          ),
        IconButton(
          icon: const Icon(Icons.image_outlined),
          tooltip: 'Joindre une photo',
          onPressed: _pickImage,
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Votre message...'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filled(
          onPressed: _canSend ? _submit : _startRecording,
          icon: Icon(_canSend ? Icons.send_rounded : Icons.mic_none_rounded),
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

/// Small breathing red dot indicating an active recording — a cheap, clear
/// "you are live" signal without needing a real waveform visualization.
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
