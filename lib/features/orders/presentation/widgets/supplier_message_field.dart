import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';

import '../../domain/entities/fulfillment.dart';
import '../providers/checkout_providers.dart';
import 'voice_note_player.dart';

/// A single "note to the supplier" slot — either written or spoken, never
/// both. Shows a compact summary row; tapping it opens a bottom sheet to
/// record/type the message, matching the mic + text composer already used
/// by the chat and comments features (features/chat/.../chat_composer.dart,
/// features/comments/.../comment_composer.dart), duplicated here rather
/// than shared since this one replaces a single value instead of appending
/// to a thread.
class SupplierMessageField extends ConsumerWidget {
  const SupplierMessageField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(supplierMessageTypeProvider);
    final text = ref.watch(supplierMessageTextProvider);
    final voicePath = ref.watch(supplierMessageVoicePathProvider);
    final voiceDuration = ref.watch(supplierMessageVoiceDurationProvider);
    final scheme = Theme.of(context).colorScheme;

    void clear() {
      ref.read(supplierMessageTypeProvider.notifier).state =
          SupplierMessageType.none;
      ref.read(supplierMessageTextProvider.notifier).state = '';
      ref.read(supplierMessageVoicePathProvider.notifier).state = null;
      ref.read(supplierMessageVoiceDurationProvider.notifier).state = null;
    }

    return InkWell(
      onTap: () => _openComposer(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: switch (type) {
                SupplierMessageType.none => Text(
                  'Message pour le fournisseur',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SupplierMessageType.text => Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SupplierMessageType.voice => voicePath == null
                    ? const SizedBox.shrink()
                    : VoiceNotePlayer(
                        path: voicePath,
                        durationSeconds: voiceDuration,
                        compact: true,
                      ),
              },
            ),
            if (type != SupplierMessageType.none)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Supprimer',
                onPressed: clear,
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Future<void> _openComposer(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: const _SupplierMessageComposerSheet(),
      ),
    );
  }
}

class _SupplierMessageComposerSheet extends ConsumerStatefulWidget {
  const _SupplierMessageComposerSheet();

  @override
  ConsumerState<_SupplierMessageComposerSheet> createState() =>
      _SupplierMessageComposerSheetState();
}

class _SupplierMessageComposerSheetState
    extends ConsumerState<_SupplierMessageComposerSheet> {
  late final _controller = TextEditingController(
    text: ref.read(supplierMessageTypeProvider) == SupplierMessageType.text
        ? ref.read(supplierMessageTextProvider)
        : '',
  );
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

  void _submitText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(supplierMessageTypeProvider.notifier).state =
        SupplierMessageType.text;
    ref.read(supplierMessageTextProvider.notifier).state = text;
    ref.read(supplierMessageVoicePathProvider.notifier).state = null;
    ref.read(supplierMessageVoiceDurationProvider.notifier).state = null;
    Navigator.of(context).pop();
  }

  void _showAccessDeniedSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        '${dir.path}/supplier_msg_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      ref.read(supplierMessageTypeProvider.notifier).state =
          SupplierMessageType.voice;
      ref.read(supplierMessageVoicePathProvider.notifier).state = path;
      ref.read(supplierMessageVoiceDurationProvider.notifier).state = duration;
      ref.read(supplierMessageTextProvider.notifier).state = '';
      if (mounted) Navigator.of(context).pop();
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

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Message pour le fournisseur',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isRecording)
            _recordingRow(scheme)
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Écrivez un message...',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  onPressed: _controller.text.trim().isEmpty
                      ? _startRecording
                      : _submitText,
                  icon: Icon(
                    _controller.text.trim().isEmpty
                        ? Icons.mic_none_rounded
                        : Icons.send_rounded,
                  ),
                ),
              ],
            ),
        ],
      ),
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
