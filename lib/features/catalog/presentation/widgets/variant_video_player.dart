import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/di/providers.dart';

/// Lecteur de la courte vidéo d'une variante, ouvert en plein écran depuis
/// la fiche produit (`showVariantVideo`).
///
/// Même convention que `ResolvedImage` : l'entité ne stocke qu'un **chemin
/// d'objet** Storage, résolu en URL au moment de l'affichage — jamais une
/// URL persistée, qui finirait périmée. Les deux buckets concernés
/// (`product-videos`, `0044` ; `review-media`, `0061`) sont publics, donc
/// `getPublicUrl` suffit, sans signature.
///
/// [bucket] est paramétrable depuis que les avis portent aussi une vidéo :
/// le lecteur est le même, seule la provenance change.
class VariantVideoPlayer extends ConsumerStatefulWidget {
  const VariantVideoPlayer({
    super.key,
    required this.videoPath,
    this.bucket = 'product-videos',
  });

  final String videoPath;
  final String bucket;

  @override
  ConsumerState<VariantVideoPlayer> createState() => _VariantVideoPlayerState();
}

class _VariantVideoPlayerState extends ConsumerState<VariantVideoPlayer> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = ref
        .read(supabaseClientProvider)
        .storage
        .from(widget.bucket)
        .getPublicUrl(widget.videoPath);
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        // Fermé pendant le chargement : sans ça le contrôleur survit à
        // l'écran qui l'a demandé, et continue de décoder dans le vide.
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    final Widget body;
    if (_error != null) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Cette vidéo n\'a pas pu être lue.',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    } else if (controller == null) {
      body = const CircularProgressIndicator(color: Colors.white);
    } else {
      body = AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: GestureDetector(
          onTap: () => setState(() {
            controller.value.isPlaying ? controller.pause() : controller.play();
          }),
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              // Le voile et l'icône n'apparaissent qu'en pause : une vidéo
              // de quelques secondes se regarde sans habillage.
              if (!controller.value.isPlaying)
                const DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black38),
                  child: Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(controller, allowScrubbing: true),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Center(child: body),
        Positioned(
          top: AppSpacing.sm,
          right: AppSpacing.sm,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ouvre [videoPath] en plein écran, sur fond noir.
Future<void> showVariantVideo(
  BuildContext context,
  String videoPath, {
  String bucket = 'product-videos',
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: VariantVideoPlayer(videoPath: videoPath, bucket: bucket),
    ),
  );
}
