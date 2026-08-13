import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/core/di/providers.dart';

/// Turns a stored image reference back into something displayable.
/// Entities only ever store an **asset path** (`assets/...`, bundled demo
/// photos) or a Supabase Storage **object path** (`<supplierId>/<file>`,
/// see `uploadPickedImage`) — never a resolved URL, so a signed URL never
/// gets persisted stale. The object path is resolved to a public URL here,
/// at display time, via `getPublicUrl` (every image bucket is public-read).
class ResolvedImage extends ConsumerWidget {
  const ResolvedImage({
    super.key,
    required this.path,
    required this.bucket,
    this.fit = BoxFit.cover,
    this.errorBuilder,
  });

  final String path;
  final String bucket;
  final BoxFit fit;

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
      return Image.asset(path, fit: fit, errorBuilder: onError);
    }
    final client = ref.watch(supabaseClientProvider);
    final url = client.storage.from(bucket).getPublicUrl(path);
    return Image.network(url, fit: fit, errorBuilder: onError);
  }
}
