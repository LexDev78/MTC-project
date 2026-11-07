import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

/// Turns a stored image reference back into something displayable.
/// Entities only ever store an **asset path** (`assets/...`, bundled demo
/// photos) or a Supabase Storage **object path** (`<supplierId>/<file>`,
/// see `uploadPickedImage`) — never a resolved URL, so a signed URL never
/// gets persisted stale. The object path is resolved at display time: via
/// `getPublicUrl` for the public-read buckets (`product-images`,
/// `supplier-branding`, `comment-attachments`), or via a fresh
/// `createSignedUrl` call when [signed] is set — required for the private
/// buckets (`chat-attachments`, `order-messages`, `kyc-documents`), whose
/// Storage RLS rejects an unauthenticated `getPublicUrl` fetch entirely.
class ResolvedImage extends ConsumerWidget {
  const ResolvedImage({
    super.key,
    required this.path,
    required this.bucket,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.signed = false,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String path;
  final String bucket;
  final BoxFit fit;

  /// Whether [bucket] is private and [path] needs a signed URL rather than
  /// a plain public one.
  final bool signed;

  /// Decode target size in physical pixels, forwarded straight to
  /// `Image.asset`/`Image.network` — set these on any call site rendered at
  /// a small, repeated size (grid/list thumbnails) so the image decoder
  /// doesn't allocate a full-resolution bitmap just to downscale it for
  /// display. `null` (the default) keeps the previous full-resolution
  /// behavior, e.g. for a single hero/detail image worth full quality.
  final int? cacheWidth;
  final int? cacheHeight;

  /// Defaults to a generic broken-image icon — pass this to show something
  /// more specific instead (e.g. `ProductImage`'s category icon fallback).
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)?
  errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onError =
        errorBuilder ??
        (context, error, stackTrace) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        );

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: onError,
        frameBuilder: _frameBuilder,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }
    final client = ref.watch(supabaseClientProvider);
    if (!signed) {
      final url = client.storage.from(bucket).getPublicUrl(path);
      return Image.network(
        url,
        fit: fit,
        errorBuilder: onError,
        frameBuilder: _frameBuilder,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
    }
    return FutureBuilder<String>(
      future: client.storage.from(bucket).createSignedUrl(path, 3600),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          );
        }
        return Image.network(
          snapshot.data!,
          fit: fit,
          errorBuilder: onError,
          frameBuilder: _frameBuilder,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
        );
      },
    );
  }

  /// Tient la place de l'image tant que sa première frame n'est pas
  /// décodée. Sans ça, `Image` ne peint **rien** pendant ce laps de temps —
  /// pas une image grise, un trou transparent — et la carte s'affiche avec
  /// un vide à la place de la photo. C'est visible sur un vrai appareil dès
  /// que la liste défile ou que le réseau traîne (constaté sur le tableau
  /// de bord fournisseur, où les deux dernières vignettes manquaient alors
  /// que les mêmes produits s'affichaient bien ailleurs).
  ///
  /// `StackFit.passthrough` transmet les contraintes du parent aux deux
  /// enfants : le substitut occupe exactement la boîte que l'image
  /// occupera, donc rien ne bouge au moment de la bascule.
  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    // Déjà en cache : peint du premier coup, aucun substitut à montrer
    // (et aucun fondu, qui ne ferait que retarder une image prête).
    if (wasSynchronouslyLoaded) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
        AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 180),
          child: child,
        ),
      ],
    );
  }
}
