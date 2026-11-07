import 'package:flutter/material.dart';

import 'package:mtc_app/app/theme/app_spacing.dart';
import 'package:mtc_app/core/widgets/resolved_image.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:mtc_app/features/catalog/presentation/widgets/variant_video_player.dart';

/// Le bucket des médias d'avis (`0061`), public en lecture comme les avis
/// qu'ils accompagnent.
const reviewMediaBucket = 'review-media';

/// Bande de vignettes : photos cliquables, vidéo jouable.
///
/// Les chemins Storage ne sont jamais persistés en URL — ils sont résolus à
/// l'affichage, comme partout ailleurs (`ResolvedImage`).
class MediaStrip extends StatelessWidget {
  const MediaStrip({
    super.key,
    required this.imagePaths,
    this.videoPath,
    this.thumbnailSize = 72,
  });

  final List<String> imagePaths;
  final String? videoPath;
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty && videoPath == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: thumbnailSize,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (var i = 0; i < imagePaths.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: GestureDetector(
                  onTap: () => showFullscreenImageViewer(
                    context,
                    images: imagePaths,
                    initialIndex: i,
                    bucket: reviewMediaBucket,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: SizedBox(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      child: ResolvedImage(
                        path: imagePaths[i],
                        bucket: reviewMediaBucket,
                        cacheWidth: 200,
                      ),
                    ),
                  ),
                ),
              ),
            if (videoPath != null)
              GestureDetector(
                onTap: () => showVariantVideo(
                  context,
                  videoPath!,
                  bucket: reviewMediaBucket,
                ),
                child: Container(
                  width: thumbnailSize,
                  height: thumbnailSize,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.play_circle_outline_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
