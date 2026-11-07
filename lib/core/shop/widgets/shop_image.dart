import 'package:flutter/material.dart';

import 'package:mtc_app/core/widgets/resolved_image.dart';

import '../shop_tokens.dart';

/// Une image du stockage, arrondie — le `NetworkImageWithLoader` du kit.
///
/// Passe par `ResolvedImage` (chemins d'asset, buckets publics ou signés,
/// repli si le fichier manque) : jamais d'URL construite à la main ici.
class ShopImage extends StatelessWidget {
  const ShopImage(
    this.path, {
    super.key,
    this.bucket = 'product-images',
    this.radius = ShopSizes.radius,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
  });

  /// `null` quand le produit n'a pas encore de photo.
  final String? path;
  final String bucket;
  final double radius;
  final BoxFit fit;

  /// Le réseau est lent : on décode à la taille affichée, pas à celle du
  /// fichier.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chemin = path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.expand(
        child: chemin == null || chemin.isEmpty
            ? ColoredBox(
                color: scheme.surfaceContainerHigh,
                child: Icon(
                  Icons.image_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              )
            : ResolvedImage(
                path: chemin,
                bucket: bucket,
                fit: fit,
                cacheWidth: cacheWidth,
              ),
      ),
    );
  }
}
