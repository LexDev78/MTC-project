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
  });

  final String path;
  final String bucket;
  final BoxFit fit;

  /// Whether [bucket] is private and [path] needs a signed URL rather than
  /// a plain public one.
  final bool signed;

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
    if (!signed) {
      final url = client.storage.from(bucket).getPublicUrl(path);
      return Image.network(url, fit: fit, errorBuilder: onError);
    }
    return FutureBuilder<String>(
      future: client.storage.from(bucket).createSignedUrl(path, 3600),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
          );
        }
        return Image.network(snapshot.data!, fit: fit, errorBuilder: onError);
      },
    );
  }
}
