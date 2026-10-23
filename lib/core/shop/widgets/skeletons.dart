import 'package:flutter/material.dart';

import '../shop_tokens.dart';

/// Le chargement du kit : des formes grises à la place du contenu, plutôt
/// qu'une roue qui tourne. Elles disent ce qui arrive et où — et sur un
/// réseau lent, l'écran a l'air prêt avant ses données.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.layer = 1,
    this.radius = ShopSizes.padding,
  });

  final double? height, width;

  /// Les formes superposées s'assombrissent d'un cran par couche.
  final int layer;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final couleur = IconTheme.of(context).color ?? Colors.black;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.04 * layer),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class CircleSkeleton extends StatelessWidget {
  const CircleSkeleton({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final couleur = IconTheme.of(context).color ?? Colors.black;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.04),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// La silhouette d'une carte produit verticale.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: ShopSizes.productCardHeight,
      width: ShopSizes.productCardWidth,
      child: Padding(
        padding: EdgeInsets.all(ShopSizes.padding / 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 1.15, child: Skeleton()),
            Spacer(flex: 2),
            Skeleton(height: 12, width: 64),
            Spacer(flex: 2),
            Skeleton(height: 12),
            Spacer(),
            Skeleton(height: 12),
            Spacer(flex: 2),
            Skeleton(height: 12, width: 80),
            Spacer(),
          ],
        ),
      ),
    );
  }
}

/// La silhouette d'une carte produit horizontale.
class SecondaryProductCardSkeleton extends StatelessWidget {
  const SecondaryProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: ShopSizes.secondaryProductCardHeight,
      width: ShopSizes.secondaryProductCardWidth,
      child: Padding(
        padding: EdgeInsets.all(ShopSizes.padding / 2),
        child: Row(
          children: [
            AspectRatio(aspectRatio: 1.15, child: Skeleton()),
            SizedBox(width: ShopSizes.padding / 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 12, width: 64),
                  Spacer(),
                  Skeleton(height: 12),
                  SizedBox(height: ShopSizes.padding / 4),
                  Skeleton(height: 12),
                  Spacer(flex: 2),
                  Skeleton(height: 12, width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une bannière en cours de chargement, à la proportion de la vraie.
class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key, this.aspectRatio = 1.87});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: const Skeleton(radius: 0),
    );
  }
}
